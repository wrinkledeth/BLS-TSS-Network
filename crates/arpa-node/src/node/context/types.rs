use super::{
    chain::{types::GeneralMainChain, Chain, MainChainFetcher},
    CommitterServerStarter, Context, ContextFetcher, ManagementServerStarter, TaskWaiter,
};
use crate::node::{
    committer::server as committer_server,
    management::server as management_server,
    queue::event_queue::EventQueue,
    scheduler::{
        dynamic::SimpleDynamicTaskScheduler, fixed::SimpleFixedTaskScheduler, TaskScheduler,
    },
};
use arpa_node_contract_client::{
    adapter::AdapterClientBuilder, controller::ControllerClientBuilder,
    coordinator::CoordinatorClientBuilder, provider::ChainProviderBuilder,
};
use arpa_node_core::{
    ChainIdentity, RandomnessTask, RpcServerType, SchedulerResult, TaskType, CONFIG,
    DEFAULT_DYNAMIC_TASK_CLEANER_INTERVAL_MILLIS,
};
use arpa_node_dal::{
    BLSTasksFetcher, BLSTasksUpdater, ContextInfoUpdater, GroupInfoFetcher, GroupInfoUpdater,
    NodeInfoFetcher, NodeInfoUpdater,
};
use async_trait::async_trait;
use log::error;
use std::sync::Arc;
use threshold_bls::group::PairingCurve;
use tokio::sync::RwLock;

#[derive(Debug)]
pub struct GeneralContext<
    N: NodeInfoFetcher<C> + NodeInfoUpdater<C> + ContextInfoUpdater,
    G: GroupInfoFetcher<C> + GroupInfoUpdater<C> + ContextInfoUpdater,
    T: BLSTasksFetcher<RandomnessTask> + BLSTasksUpdater<RandomnessTask>,
    I: ChainIdentity + ControllerClientBuilder<C> + CoordinatorClientBuilder + AdapterClientBuilder,
    C: PairingCurve,
> {
    main_chain: GeneralMainChain<N, G, T, I, C>,
    eq: Arc<RwLock<EventQueue>>,
    ts: Arc<RwLock<SimpleDynamicTaskScheduler>>,
    f_ts: Arc<RwLock<SimpleFixedTaskScheduler>>,
}

impl<
        N: NodeInfoFetcher<C> + NodeInfoUpdater<C> + ContextInfoUpdater + Sync + Send + 'static,
        G: GroupInfoFetcher<C> + GroupInfoUpdater<C> + ContextInfoUpdater + Sync + Send + 'static,
        T: BLSTasksFetcher<RandomnessTask> + BLSTasksUpdater<RandomnessTask> + Sync + Send + 'static,
        I: ChainIdentity
            + ControllerClientBuilder<C>
            + CoordinatorClientBuilder
            + AdapterClientBuilder
            + ChainProviderBuilder
            + Sync
            + Send
            + 'static,
        C: PairingCurve,
    > GeneralContext<N, G, T, I, C>
{
    pub fn new(main_chain: GeneralMainChain<N, G, T, I, C>) -> Self {
        GeneralContext {
            main_chain,
            eq: Arc::new(RwLock::new(EventQueue::new())),
            ts: Arc::new(RwLock::new(SimpleDynamicTaskScheduler::new())),
            f_ts: Arc::new(RwLock::new(SimpleFixedTaskScheduler::new())),
        }
    }
}

impl<
        N: NodeInfoFetcher<C>
            + NodeInfoUpdater<C>
            + ContextInfoUpdater
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        G: GroupInfoFetcher<C>
            + GroupInfoUpdater<C>
            + ContextInfoUpdater
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        T: BLSTasksFetcher<RandomnessTask>
            + BLSTasksUpdater<RandomnessTask>
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        I: ChainIdentity
            + ControllerClientBuilder<C>
            + CoordinatorClientBuilder
            + AdapterClientBuilder
            + ChainProviderBuilder
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        C: PairingCurve + std::fmt::Debug + Clone + Sync + Send + 'static,
    > Context for GeneralContext<N, G, T, I, C>
{
    type MainChain = GeneralMainChain<N, G, T, I, C>;

    async fn deploy(self) -> SchedulerResult<ContextHandle> {
        self.get_main_chain().init_components(&self).await?;

        let f_ts = self.get_fixed_task_handler();

        let rpc_endpoint = self
            .get_main_chain()
            .get_node_cache()
            .read()
            .await
            .get_node_rpc_endpoint()
            .unwrap()
            .to_string();

        let management_server_rpc_endpoint =
            CONFIG.get().unwrap().node_management_rpc_endpoint.clone();

        let context = Arc::new(RwLock::new(self));

        f_ts.write()
            .await
            .start_committer_server(rpc_endpoint, context.clone())?;

        f_ts.write()
            .await
            .start_management_server(management_server_rpc_endpoint, context.clone())?;

        let ts = context.read().await.get_dynamic_task_handler();

        Ok(ContextHandle { ts })
    }
}

impl<
        N: NodeInfoFetcher<C>
            + NodeInfoUpdater<C>
            + ContextInfoUpdater
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        G: GroupInfoFetcher<C>
            + GroupInfoUpdater<C>
            + ContextInfoUpdater
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        T: BLSTasksFetcher<RandomnessTask>
            + BLSTasksUpdater<RandomnessTask>
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        I: ChainIdentity
            + ControllerClientBuilder<C>
            + CoordinatorClientBuilder
            + AdapterClientBuilder
            + ChainProviderBuilder
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        C: PairingCurve + std::fmt::Debug + Clone + Sync + Send + 'static,
    > ContextFetcher<GeneralContext<N, G, T, I, C>> for GeneralContext<N, G, T, I, C>
{
    fn get_main_chain(&self) -> &<GeneralContext<N, G, T, I, C> as Context>::MainChain {
        &self.main_chain
    }

    fn get_fixed_task_handler(&self) -> Arc<RwLock<SimpleFixedTaskScheduler>> {
        self.f_ts.clone()
    }

    fn get_dynamic_task_handler(&self) -> Arc<RwLock<SimpleDynamicTaskScheduler>> {
        self.ts.clone()
    }

    fn get_event_queue(&self) -> Arc<RwLock<EventQueue>> {
        self.eq.clone()
    }
}

pub struct ContextHandle {
    ts: Arc<RwLock<SimpleDynamicTaskScheduler>>,
}

#[async_trait]
impl TaskWaiter for ContextHandle {
    async fn wait_task(&self) {
        loop {
            while !self.ts.read().await.dynamic_tasks.is_empty() {
                let (task_recv, task_monitor) = self.ts.write().await.dynamic_tasks.pop().unwrap();

                let _ = task_recv.await;

                if let Some(monitor) = task_monitor {
                    monitor.abort();
                }
            }

            tokio::time::sleep(std::time::Duration::from_millis(
                DEFAULT_DYNAMIC_TASK_CLEANER_INTERVAL_MILLIS,
            ))
            .await;
        }
    }
}

impl<
        N: NodeInfoFetcher<C>
            + NodeInfoUpdater<C>
            + ContextInfoUpdater
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        G: GroupInfoFetcher<C>
            + GroupInfoUpdater<C>
            + ContextInfoUpdater
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        T: BLSTasksFetcher<RandomnessTask>
            + BLSTasksUpdater<RandomnessTask>
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        I: ChainIdentity
            + ControllerClientBuilder<C>
            + CoordinatorClientBuilder
            + AdapterClientBuilder
            + ChainProviderBuilder
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        C: PairingCurve + std::fmt::Debug + Clone + Sync + Send + 'static,
    > CommitterServerStarter<GeneralContext<N, G, T, I, C>> for SimpleFixedTaskScheduler
{
    fn start_committer_server(
        &mut self,
        rpc_endpoint: String,
        context: Arc<RwLock<GeneralContext<N, G, T, I, C>>>,
    ) -> SchedulerResult<()> {
        self.add_task(TaskType::RpcServer(RpcServerType::Committer), async move {
            if let Err(e) = committer_server::start_committer_server(rpc_endpoint, context).await {
                error!("{:?}", e);
            };
        })
    }
}

impl<
        N: NodeInfoFetcher<C>
            + NodeInfoUpdater<C>
            + ContextInfoUpdater
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        G: GroupInfoFetcher<C>
            + GroupInfoUpdater<C>
            + ContextInfoUpdater
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        T: BLSTasksFetcher<RandomnessTask>
            + BLSTasksUpdater<RandomnessTask>
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        I: ChainIdentity
            + ControllerClientBuilder<C>
            + CoordinatorClientBuilder
            + AdapterClientBuilder
            + ChainProviderBuilder
            + std::fmt::Debug
            + Clone
            + Sync
            + Send
            + 'static,
        C: PairingCurve + std::fmt::Debug + Clone + Sync + Send + 'static,
    > ManagementServerStarter<GeneralContext<N, G, T, I, C>> for SimpleFixedTaskScheduler
{
    fn start_management_server(
        &mut self,
        rpc_endpoint: String,
        context: Arc<RwLock<GeneralContext<N, G, T, I, C>>>,
    ) -> SchedulerResult<()> {
        self.add_task(TaskType::RpcServer(RpcServerType::Management), async move {
            if let Err(e) = management_server::start_management_server(rpc_endpoint, context).await
            {
                error!("{:?}", e);
            };
        })
    }
}
