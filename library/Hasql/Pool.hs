module Hasql.Pool
(   Pool
,   Settings(..)
,   UsageError(..)
,   withConnection
,   acquire
,   acquireWith
,   release
,   use
,   useWithObserver
,   getPoolUsageStat
)
where

import qualified Data.Pool as ResourcePool
import           System.Clock (Clock(Monotonic), diffTimeSpec, getTime, toNanoSecs)

import           Hasql.Pool.Prelude
import qualified Hasql.Connection
import qualified Hasql.Session
import qualified Hasql.Pool.ResourcePool as ResourcePool
import           Hasql.Pool.Observer (Observed(..), ObserverAction)


-- |
-- A pool of connections to DB.
newtype Pool =
    Pool (ResourcePool.Pool (Either Hasql.Connection.ConnectionError Hasql.Connection.Connection))
    deriving (Show)


type PoolSize         = Int
type PoolStripes      = Int
type ResidenceTimeout = NominalDiffTime

-- |
-- Connection getter action that allows for obtaining Postgres connection settings via external rsources such as AWS tokens etc.
type ConnectionGetter = IO (Either Hasql.Connection.ConnectionError Hasql.Connection.Connection)

-- |
-- Settings of the connection pool. Consist of:
--
-- * Pool-size.
--
-- * Timeout.
-- An amount of time for which an unused resource is kept open.
-- The smallest acceptable value is 0.5 seconds.
--
-- * Connection settings.
--
type Settings =
  (PoolSize, ResidenceTimeout, Hasql.Connection.Settings)

-- |
-- Given the pool-size, timeout and connection settings
-- create a connection-pool.
acquire :: Settings -> IO Pool
acquire settings@(_size, _timeout, connectionSettings) =
    acquireWith stripes (Hasql.Connection.acquire connectionSettings) settings
    where
        stripes = 1


-- |
-- Similar to 'acquire', allows for finer configuration.
acquireWith :: PoolStripes
            -> ConnectionGetter
            -> Settings
            -> IO Pool
acquireWith stripes connGetter (size, timeout, connectionSettings) =
    fmap Pool $
        ResourcePool.createPool connGetter release stripes timeout size
    where
        release = either (const (pure ())) Hasql.Connection.release


-- |
-- Release the connection-pool.
release :: Pool -> IO ()
release (Pool pool) =
    ResourcePool.destroyAllResources pool


-- |
-- A union over the connection establishment error and the session error.
data UsageError
    =   ConnectionError Hasql.Connection.ConnectionError
    |   SessionError    Hasql.Session.QueryError
    deriving (Show, Eq)

-- |
-- Use a connection from the pool to run a session and
-- return the connection to the pool, when finished.
use :: Pool -> Hasql.Session.Session a -> IO (Either UsageError a)
use = useWithObserver Nothing

-- |
-- Same as 'use' but allows for a custom observer action. You can use it for gathering latency metrics.
useWithObserver :: Maybe ObserverAction
                -> Pool
                -> Hasql.Session.Session a
                -> IO (Either UsageError a)
useWithObserver observer (Pool pool) session =
    fmap (either (Left . ConnectionError) (either (Left . SessionError) Right)) $
    ResourcePool.withResourceOnEither pool $
    traverse runQuery
    where
        runQuery dbConn = maybe action (runWithObserver action) observer
            where
                action = Hasql.Session.run session dbConn

        runWithObserver action doObserve = do
            let measure = getTime Monotonic
            start  <- measure
            result <- action
            end    <- measure
            let nsRatio  = 1000000000
                observed = Observed {   latency = toRational (toNanoSecs (end `diffTimeSpec` start) % nsRatio)
                                    }
            doObserve observed >> pure result

-- |
-- Use a 'Connection' from the 'Pool'
withConnection :: Pool -> (Connection -> IO a) -> IO (Either Hasql.Connection.ConnectionError a)
withConnection (Pool p) f =
  ResourcePool.withResource p $
    either (return . Left) (fmap Right . f)


getPoolStats :: Pool -> IO ResourcePool.Stats
getPoolStats (Pool p) = ResourcePool.stats p performStatsReset where
    performStatsReset = False


getPoolUsageStat :: Pool -> IO PoolSize
getPoolUsageStat pool = getPoolStats pool >>= gather where
    gather = pure . ResourcePool.currentUsage . ResourcePool.poolStats
