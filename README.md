# Virtual Infrastructure Orchestration for Cloud Service Deployment
A toolkit to automate the initial infrastructure setup for deployment of various OpenStack distributions.

## Clone & Run:
Follow the steps below to clone and run for the distribution of your choice:

```bash
git clone https://github.com/arslan-qadeer/droid.git
```

## Usage

Please make sure that you have enough hardware resources for the VMs to spin up. Prior to run infrastructure setup, please consider to download [UBUNTUSERVER.BOX](https://drive.google.com/file/d/1KrWEQ0IB-YMsqlNT4emN5LOAJ2X0vG_X/view?usp=sharing) and [RHELSERVER.BOX](https://drive.google.com/file/d/15iEFJ0z9sKpbqbKT7mBmO0QivOxzqOaX/view?usp=sharing), and copy them in the main directory (droid).

```bash
cd droid

./pod_bringup.sh
```

## Roadmap

Generalize this toolkit for more cloud based deployments e.g. Kubernetes, Mesos, Docker Swarm etc.
