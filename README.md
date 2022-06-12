hasql-resource-pool
===================

This is a fork of [hasql-pool](https://github.com/nikita-volkov/hasql-pool) that
continues using [resource-pool](https://hackage.haskell.org/package/resource-pool) for
the underlying pool implementation.

The fork is based on [0.5.2.2 release](https://hackage.haskell.org/package/hasql-pool)
(as the latest original implementation based on `resource-pool`), and it includes the following API and layout changes:

* Connections are based on settings with IO actions.
  This change to the API makes the library usable with the custom authentication methods
  such as [AWS RDS IAM tokens](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html).
* Pool interface allows for specifying IO observer actions. These actions are useful for collecting and tracking various pool metrics
  with tools like [Prometheus](https://prometheus.io/docs/introduction/overview/).
* No reliance on Stack tooling.
