FROM ubuntu:22.04

WORKDIR /app

# Update and Python install
RUN apt-get update -y && apt-get install -y python3-pip && pip3 install --upgrade pip

# Install NodeJS and proxy
RUN apt-get install npm nodejs -y && \
    npm install -g configurable-http-proxy

# Jupyter installation
RUN pip3 install jupyterhub && \
    pip3 install jupyterlab && \
    pip3 install --upgrade notebook

# Add essential libs
RUN pip3 install jupyterhub-ldapauthenticator jupyterhub-ldapcreateusers pandas scipy matplotlib wheel ipywidgets papermill petl && \
    pip3 install "dask[distributed,dataframe]" && \   
    pip3 install dask_labextension

# Install sudo for admin operations from JupyterHub
RUN apt-get -y install sudo nano

# Add default admin user
RUN useradd admin && echo admin:vixtract | chpasswd
RUN mkdir /home/admin && chown admin:admin /home/admin
RUN usermod -a -G sudo admin

# Give write permissions to admin for /usr/local/lib
# which will allow us to install libs globally from this acc in Jupyter
RUN chgrp -R admin /usr/local/lib && chmod -R 775 /usr/local/lib

# Copy configs and scripts
COPY ./jupyterhub_config.py .
COPY ./create-user.py .

# Allow dots in system usernames
COPY ./adduser.conf /etc

# Volumes for keeping new users, Python libs
VOLUME /app
VOLUME /home
VOLUME /etc
VOLUME /usr/local/lib/python3.10/dist-packages

EXPOSE 8000

#ENTRYPOINT ["jupyterhub", "--ip=0.0.0.0", "--port=8000", "--no-ssl", "-f", "/app/jupyterhub_config.py"]

ENTRYPOINT ["jupyterhub", "-f", "/app/jupyterhub_config.py"]
