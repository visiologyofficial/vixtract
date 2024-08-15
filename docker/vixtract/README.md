# ViXtract
 ***
Simple open source ETL tool based on Python with the next common pipeline:
* Fetch data from any sources in JupyterLab.
* Transfrom data with **PETL** or another lib.
* Extract processed data into **PostgreSQL**.
* Schedule these operations in **Cronicle**.
* Take data from PostgreSQL into Visiology Analytics Platform or similar software for analysis.

## 1. About this build

* It incorporates 4 components running in Docker containers: PostgreSQL, Jupyter, Cronicle, Nginx.
* There are no automation scripts for launching or configuring. Every component should be configured separately according to its documentation.
* The main goal for this build is packing ViXtract into Docker for easy and enviroment-agnostic deployment.
* This build does not contain all features from host-based deployment.
* The current version does not claim to be a robust, fully tested and complete solution for running in productive enviroments with a huge number of users. There are a lot improvements and features must be implemented before that and they are mostly related to proper JupyterHub deployment and migrating to k8s.
* All limitations and features will be described in tech details section below.
***
## 2. Prerequisites

* Development and testing are performed in Ubuntu Server 22.04, but any OS with Docker support should work as well.
* Docker 19+ and Docker Compose 1.29+. Tested on Docker 20.10.12 and Compose 2.5.0.
* Hardware requirements depend on the tasks and should be calculated according to JupyterHub, Nginx and PostgreSQL recomendations. The good example for simple tasks and small team is 4 CPU, 4 GB RAM, 40 Gb SSD.
* All instructions are written for servers with access to the Internet.

## 3. Installation

Run the next command which will create vixtract folder, download yml file and start all Vixtract components.
   ```
   mkdir vixtract && cd vixtract/ && \
   wget https://raw.githubusercontent.com/visiologyofficial/vixtract/master/docker/vixtract/docker-compose.yml && \
   docker-compose up -d
   ```
All Docker images will be pulled from Docker Hub. Check with `docker-compose ps` that all containers are up and running and go to http://{server_address}:80 to open Vixtract web interface.
***

## 4. Tech details

### Postgres

* It is an official image without any modifications, read the details here: https://github.com/docker-library/docs/blob/master/postgres/README.md
* Default password `vixtract` for user `postgres`  is set in `docker-compose.yml`.
* Postgres preserves its data in `/var/lib/docker/volumes/vixtract_postgresql` folder on the host machine.
* There is no point to change `postres` password in `docker-compose.yml` if container has already been started at least one time and created its volume in `/var/lib/docker...`. It does not affect anything. Use another postgresql build-in methods to change password instead, for example, this command in Linux terminal:
   ```
   docker exec $(docker ps | grep vixtract_postgresql | awk '{print $1}') su postgres \
   bash -c "psql -c \"ALTER USER postgres WITH PASSWORD 'some-password';\""
   ```
* By default port **5432** is opened and there are to limitations to connect from any **IP** or with any **user**. In future builds postgresql will be hidden behind Nginx. As for now some additional actions for servers exposed to the Internet are highly recommended: closing port by commenting out two lines in `docker-compose.yml` or allowing connection from some IP or network interface only - see posgtresql documention for the details.


### Jupyter:

* It is custom image with ubuntu:22.04 as a base layer.
* Python 3.10, jupyterhub, jupyterlab and relevant set of Python libs are added.
* Added system user account in OS with credentials: `admin/vixtract`.
* This `admin` account was added in admin list in `jupyterhub_config.py`.
* This `admin` account has write permissions for `/usr/local/lib`, which gives this user an ability to install Python libs globally.
* All OS accounts, libs and Jupyterhub files are preserved in several named Docker volumes in `/var/lib/docker/volumes/vixtract_jupyterhub...`. It is far from best practices to persists data in `/etc`, `/home` via Docker volumes, so this mechanism will definitely be changed in future builds. Now it is working and fastly implemeted compromise.


### Cronicle

* It is custom image with ubuntu:22.04 as a base layer.
* Persists Cronicle data in named Docker volume in `/var/lib/docker/volumes/vixtract_cronicle-data`.
* **Jupyter** home and Python libs volumes were added as read-only mount points. It allows to use shell scripts in **Cronicle** without any additional manipulations: all notebooks and Python libs are already accessible in **Cronicle** shell scripts.
* There is an important record in `docker-compose.yml` for cronicle service: 
  ```
  hostname: vixtract_primary-cronicle-server
  ``` 
  This option is critical when using Docker Stack only (deploying Vixtract with Visiology Platform), so in case of Docker Compose it can be neglected. 
  Explanation: in case of Docker Stack every container is assigned a new unique name like `vixtract_cronicle.1.q3u0kexln3dzg87nktdtylzqt` every times it is created. This name is used by Cronicle for its server match - see settings in Cronicle web interface http://{server_address}/cronicle/#Admin?sub=servers or by command in terminal inside a container: 
  ```
  /opt/cronicle/bin/storage-cli.js get global/servers/0
  ``` 
  So, rebooting the host or creating a new container leads to endless `"waiting for masterserver"` message in web interface as Cronicle is trying to connect to the old container hostname which is no longer exists. To solve this problem we need to lock container hostname by adding this dedicated record in `docker-compose.yml`. In that case the name `vixtract_primary-cronicle-server` will always be the same and Cronicle will successfully connect to it even after starting a new container.


### Nginx

* Based on official image nginx:1.21.6.
* Added ViXtract web page and nginx.conf.
* Exposed two volumes for the web page and Nginx configs.
* 80 and 443 ports are opened - it can be seen in `docker-compose.yml`.
* Some hacks were applied in order to make Cronicle functions with `/cronicle` path in URL.

***

## 5. Quick start

1. After the installation open ViXtract home web page http://{server_address}.
2. Check all useful links on this web page and follow to JupyterHub by clicking on the button or with the exact URL http://{server_address}/jupyter.
3. Use default JupyterHub credentials `admin/vixtract` to log in.
4. Create a notebook with default ipykernel and start your journey.
5. Open Cronicle from home web page or directly with http://{server_address}/cronicle.
6. Use default Cronicle credentials `admin/admin` to log in.
7. Create a new task with shell script and schedule notebooks launching with papermill.
8. Connect to PostgreSQL with any SQL client (for example DBeaver) to database named `postgres`. Use default credentials `postgres/vixtract` if they have not been changed in `docker-compose.yml`. Connection string example:

```
jdbc:postgresql://{server_address}:5432/postgres?user=postgres&password=vixtract
```

***

## 6. Configuration and guidelines

Some setup cases will be listed below. Basically, there are three main places to perform configuring.

1. JupyterHub and Cronicle web interfaces. Details can be found in the next web sites:
   * https://github.com/jhuckaby/Cronicle | General Cronicle page and docs.
   * https://jupyterhub.readthedocs.io/en/stable/ | JupyterHub knowledge base.
   * https://jupyterlab.readthedocs.io/en/stable/ | JupyterLab wiki for working with notebooks. 

2. `docker-compose.yml`. Some settings can be applied here to trasfer them into container. Still, better to use another places and modify this file in case it is really necessary or some instrunction indicates it directly.
3. Configuration files in Docker volumes for every component: `/var/lib/docker/volumes/vixtract...`

### Adding new users

Users must be added separately in JupyterHub and in Cronicle. Optionally in PostgreSQL as well.

1. JupyterHub. 
   * All users added via Hub Control Panel have a password `vixtract` by default. There is a good article showing how to add new users and change their passwords:https://rancavil.medium.com/jupyterhub-docker-how-to-add-new-users-d41f6b39ec30
   * Presumably minimum username length is three characters in Hub Control Panel. If you need to create LDAP user with one or two characters long use LDAP dynamic user creation with first login.


2. Cronicle. Use this guide for adding Cronicle users: https://github.com/jhuckaby/Cronicle#users-tab. There are no default password - it is set manually while creating a user.
   
3. PostgreSQL. Create a user via psql in termial inside a container or via SQL client like DBeaver. Useful links:
   https://www.postgresql.org/docs/14/sql-createuser.html
   https://medium.com/coding-blocks/creating-user-database-and-adding-access-on-postgresql-8bfcd2f4a91e

### Deleting users

* No known issues for removing users in Cronicle or PostgreSQL.
* As for JupyterHub firstly remove user in Hub Control Panel http://{server_address}/jupyter/hub/admin#/. Afterwards open terminal in JupyterLab from ***admin*** user and run a command `sudo deluser --remove-home {your_user_name}`.
* Do not try to delete default ***admin*** user.
* With LDAP enabled most likely you will not be using default ***admin*** account (unless you have ***admin*** user in LDAP server and you use it for logging into JupyterHub, which is unlikely). So, execuite `su admin` in terminal firstly and then delete users with `sudo` from ***admin***.

### Installing Python libs in JupyterLab

There is no multikernel feature in JupyterHub in this build, so make sure libs do not conflict with each other.
Libs are installed in JupyterLab web interface in console or terminal with `pip3 install`.

1. To install Python libs globally for all users in JupyterHub and for Cronicle shell scripts use default `admin` account in JupyterHub. This user has write permissions for `/usr/local/lib` which is mounted to Cronicle container.
2. Other users can install Python libs in their home directories only, so each user will see his/her home libs and global libs.
3. In case LDAP is enabled and it is impossible to use ***admin*** user for working in JupyterHub execute `su admin` command in JupyterLab terminal and then install libs globally from system user ***admin***.

### Running events with notebooks in Cronicle

1. Choose a Jupyter notebook in JupyterLab to run via Cronicle. As an example lets take two notebooks 
    - `freshdesk.ipynb` (which full location inside Jupyter Docker container will be `/home/admin/freshdesk.ipynb`).
    - `apple.ipynb` (which full location inside Jupyter Docker container will be `/home/yus1/freshdesk.ipynb`)
2. As we can see `freshdesk.ipynb` is admin's notebook while `apple.ipynb` owned by user `yus1`. We can run both in Cronicle but do not forget that Python libs for Freshdesk and Apple must be installed globally from `admin` user in JupyterLab. If apple lib is installed inside JupyterLab from `yus1` user Cronicle will not see it.
3. Open Cronicle web interface and add an event in `Schedule` tab.
4. Choose `Shell script` plugin and type `papermill --cwd ./jupyter-home/admin/ ./jupyter-home/admin/freshdesk.ipynb ./jupyter-home/admin/freshdesk-output.ipynb`.
5. Finish configuring the event and save it.
6. Create another Cronicle event with `papermill --cwd ./jupyter-home/yus1/ ./jupyter-home/yus1/apple.ipynb ./jupyter-home/yus1/apple-output.ipynb` in shell script.
7. Manually run the events and see results in `Completed` tab.
### PostgreSQL guideline

* Create your own databases, users, roles, set permissions and assign connection rules according to your needs. Use official PostgreSQL documentation for that.
* Use read-only account for connecting to database from Visiology Analytics Platform or another endpoint software to avoid accidental data change in SQL requests.
* Use separate databases for every team.
* Ensure security if server is exposed to the Internet.

### LDAP

* Currently LDAP is available in JupyterHub only. 
* Python libs `jupyterhub-ldapauthenticator`, `jupyterhub-ldapcreateusers` are already included in Jupyter container.
* Source of information for JupyterHub is here: https://github.com/jupyterhub/ldapauthenticator
* Looks like Jupyter Hub Control Panel is very capricious to usernames. For example, it can't add username with two characters or with dot in name.
* With LDAP enabled creating users in Hub Control is not supported. Use dynamic creating with first login.

#### Configuration use case for JupyterHub.
1. Open `/var/lib/docker/volumes/vixtract_jupyter-config/_data/jupyterhub_config.py`.
2. Go to the end of the file and uncomment all lines in LDAP section including `c.LocalLDAPCreateUsers.create_system_users = True`.
3. Change example LDAP settings according to the guide https://github.com/jupyterhub/ldapauthenticator.
4. Add JupyterHub admin users from LDAP. Example: `c.Authenticator.admin_users = {'ldap-admin1', 'ldap-admin2'}`.
5. Save and close `jupyterhub_config.py`.
6. Restart Jupyter container `docker container restart vixtract_jupyter`.
7. Open JupyterHub web interface, enter your ldap username (example here is `ldap-admin1`) and your ldap password. This account should have admin rights for JupyterHub, but no ability to install libs globally and fully delete users. For that use `su admin` in terminal firstly.
8. After entering any valid LDAP credentials, JupyterHub user (and internal system user) will be created automatically. 


***

## 7. Enabling HTTPS

* Everything is set in Nginx config. PostgreSQL is out of this configuration scope.
* The config example encompasses use case with valid Lets Encrypt certs.
  
1. Generate Lets Encrypt certificates with certbot or another methods. Usually it is via https://certbot.eff.org/.
2. Put private and public keys (fullchain.pem and privkey.pem in this example) in `/var/lib/docker/volumes/vixtract_nginx-etc/_data/`
3. Open `/var/lib/docker/volumes/vixtract_nginx-etc/_data/nginx.conf` and uncomment all lines in 
   * `# HTTPS server optimization section`, 
   * `# Redirect HTTP to HTTPS section`, 
   * `# HTTPS section`.
4. Comment out line `listen 80;`.
5. *Optional*. If your private key is protected by password add additional line in `# HTTPS section`: `ssl_password_file   /mnt/volume/password.pass;` with your password inside.
6. Check all your settings, cert names and make sure they are correct for your use case.
7. Restart Nginx container with `docker container restart vixtract_nginx`.
8. Enjoy HTTPS in JupyterHub and Cronicle.

***

## 8. Current limitations and known issues

* The main limitation in this build is JupyterHub implementation in a container. It does not use conda enviroments as on host installation. So, you are limited to one env for Python and one kernel for Jupyter notebooks. The better approach here is DockerSpawner with separate Docker container for every env: https://github.com/jupyterhub/jupyterhub-deploy-docker

* It is impossible to use LDAP and local user accounts in JupyterHub simultaneously.

* No LDAP for Cronicle

***

## 9. Roadmap

1. Proper JupyterHub deployment from this project https://github.com/jupyterhub/jupyterhub-deploy-docker
2. Hiding PostgreSQL behind Nginx.
3. Switching to Oath for JupyterHub. Most likeky adding Keycloak for multi authentication mechanism support, easy and versatile configuring.
4. Adding LDAP/AD/OAuth support for Cronicle.
5. K8s deployment.
