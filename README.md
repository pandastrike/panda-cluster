Panda-Cluster
============

> **IMPORTANT** This project is no longer under active development.
> Based on what we've learned building this,
> we recommend looking at [Convox][] instead.

[Convox]:https://github.com/convox/rack

### Manage Huxley Clusters
---

Managing your project's infrastructure can be a little tedious.  Imagine that you want to spin-up a cluster of 10 machines on Amazon Web Services (AWS):
- You go find your favored Amazon Machine Image,
- go through the multi-page Amazon Console wizard,
- and then after it's running, you still have to fidget with the Console GUI to make any other adjustments.  

That all involves a lot of manual interaction. Panda-Cluster is here to make your life better with automation.

Panda-Cluster is part of the [Huxley Project][huxley], a tool that automates deployment.  Huxley relies on this library to allocate infrastructure resources and monitor their state.  See the [Huxley Wiki][wiki] to see more documentation.


## Requirements
panda-cluster makes use of ES6 features, including promises and generators.  Using this library requires Node 0.12+.

```shell
git clone https://github.com/creationix/nvm.git ~/.nvm
source ~/.nvm/nvm.sh && nvm install 0.12
```

Compiling the ES6 compliant CoffeeScript requires `coffee-script` 1.9+.
```shell
npm install -g coffee-script
```

## Install
Install panda-cluster locally to your project with:

```
npm install pandastrike/panda-cluster --save
```

[huxley]:https://github.com/pandastrike/huxley
[wiki]:https://github.com/pandastrike/huxley/wiki/Panda-Cluster
