### Before You Start

#### Prepare a PGP Key

To keep secrets secure, a PGP key is needed. higly recommend using Keybase to distribute you public key. head to https://keybase.io/ to find out more.

Once you've installed an sign to Keybase, click you avatar, got View/Edit profile, click Prove PGP key to add you PGP key.

On the following guide, when we using PGP key, you can provide `keybase:$YOU_ACCOUNT_ID`, for example `keybase:living42`

Also, if you are not using Keybase, you can always provide the pgp public key file instead.

#### Install Aliyun Cli

If you are using Homebrew, you can install it using command below

```sh
brew install aliyun-cli
```

or head to the official repo: https://github.com/aliyun/aliyun-cli

And you should run `aliyun configure` give it the right credentials. this project required you using root Access Key to make it work.

#### Install Docker

This project reliant Docker to build and push Container Images. you have to choice:

##### Using Docker Desktop

Go to https://www.docker.com/products/docker-desktop download and install it

##### Using remote Docker Engine

More advanced approach is connect to remote machine that runs Docker Engine, this might speed up you build and push process, if the remote machine have more bandwidth than you local macnine. but your also need docker command installed on you local.

To connect to remote Docker Engine, just `DOCKER_HOST` variable to the right address:

```sh
export DOCKER_HOST=tcp://...
```

Commonly, Docker Engine are no configured to expose tcp port, instead they bind a unix socket on `/var/run/docker.sock`, you can use `ssh -L` to forward that unix socket to you local. By doing so, run command on below in a new terminal window.

```sh
ssh ${YOU_HOST} -Nv -L 2375:/var/run/docker.sock
```

Set the `DOCKER_HOST` variable

```sh
export DOCKER_HOST=tcp://127.0.0.1:2375

docker version  # check connectivity
```

#### Install Terraform

https://learn.hashicorp.com/tutorials/terraform/install-cli

Note: This project work on Terraform 0.13.3 specifically, be sure you are installed this version

After installation, run this command on project root to initialize modules

```sh
terraform init
```

#### Install Vault

You gonna using `vault` command to control all secrets. head to https://www.vaultproject.io/docs/install

#### Install jq

For macOS with Homebrew

```
brew install jq
```

Other distro are pretty easy too

### Get Started

#### Initialize Vault

Because we are using Vault to manage secrets, the configuration process is vary manual, so we can't spin up all boxies before Vault has initialized, we need manually configure Vault first. notice you only need to do this once

Startup boxies needed for Vault configuration process

```sh
# Tell terraform to using aliyun cli's default profile, and deploy to cn-shanghai region
export ALICLOUD_PROFILE=default
export ALICLOUD_REGION=cn-shanghai

terraform apply \
    -target module.deploy.module.bastion \
    -target module.deploy.module.vault
```

Forward Vault server via bastion host, the address could find in previous command's output.

```sh
ssh -l root ${BASTION_HOST_IP} -L 8200:vault-1:8200
```

run these commands on other terminal window, to initialize Vault.

```sh
PGP_KEY=${PGP_KEY}

export VAULT_ADDR=http://vault-1:8200

vault operator init \
    -recovery-shares=1 \
    -recovery-threshold=1 \
    -recovery-pgp-keys=$PGP_KEY \
    -root-token-pgp-key=$PGP_KEY
```

You can see the Recovery Keys and Root Token print out, these are encrypted using PGP_KEY you've provided. now copy these output, save it, we're use it later.

> We are creating single recovery key, but Vault has very cool and even more secure way to generate recovery keys, you can check https://www.vaultproject.io/docs/commands/operator/init to find out more

---

TODO
