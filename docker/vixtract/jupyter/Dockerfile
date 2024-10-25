FROM quay.io/jupyterhub/jupyterhub:5

WORKDIR /app

# Add essential libs
COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt

# Install sudo for admin operations from JupyterHub
RUN apt-get update -qq > /dev/null && apt-get -y install sudo=1.9.9-1ubuntu2.4 \
            nano=6.2-1ubuntu0.1 --no-install-recommends

# Add default admin user
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]
RUN useradd admin && echo admin:vixtract | chpasswd
RUN mkdir /home/admin && chown admin:admin /home/admin
RUN usermod -a -G sudo admin

# Give write permissions to admin for /usr/local/lib
# which will allow us to install libs globally from this acc in Jupyter
RUN chgrp -R admin /usr/local && chmod -R 775 /usr/local

# Copy configs and scripts
COPY ./jupyterhub_config.py .
COPY ./create-user.py .

# Allow dots in system usernames
COPY ./adduser.conf /etc

EXPOSE 8000

#ENTRYPOINT ["jupyterhub", "--ip=0.0.0.0", "--port=8000", "--no-ssl", "-f", "/app/jupyterhub_config.py"]

ENTRYPOINT ["jupyterhub", "-f", "/app/jupyterhub_config.py"]
