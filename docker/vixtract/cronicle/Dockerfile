FROM ubuntu:22.04

# Update and Python install
RUN apt-get update -y && apt-get install curl -y && apt-get install -y python3-pip && pip3 install --upgrade pip

# Install NodeJS
RUN apt-get install npm nodejs -y

# Install Chronicle
RUN curl -s https://raw.githubusercontent.com/jhuckaby/Cronicle/master/bin/install.js | node

# Add essential libs
RUN pip3 install wheel ipywidgets papermill petl && \
    pip3 install "dask[distributed,dataframe]" && \   
    pip3 install dask_labextension

WORKDIR /opt/cronicle/bin

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3012

ENTRYPOINT ["/entrypoint.sh"]