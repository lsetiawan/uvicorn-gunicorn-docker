FROM python:3.8

LABEL maintainer="Landung Setiawan <landung.setiawan@gmail.com>"

ENV CONDA_VERSION=4.8.5-1 \
    PYTHON_VERSION=3.8 \
    CONDA_ENV=app-env \
    LANG=C.UTF-8  \
    LC_ALL=C.UTF-8 \
    CONDA_DIR=/srv/conda

ENV PYTHON_PREFIX=${CONDA_DIR}/envs/${CONDA_ENV} \
    PATH=${CONDA_DIR}/bin:${PATH}

ARG DEBIAN_FRONTEND=noninteractive

RUN echo "Installing Apt-get packages..." \
    && apt-get update --fix-missing \
    && apt-get install -y apt-utils 2> /dev/null \
    && apt-get install -y wget zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN echo "Installing Miniforge..." \
    && URL="https://github.com/conda-forge/miniforge/releases/download/${CONDA_VERSION}/Miniforge3-${CONDA_VERSION}-Linux-x86_64.sh" \
    && wget --quiet ${URL} -O miniconda.sh \
    && /bin/bash miniconda.sh -u -b -p ${CONDA_DIR} \
    && rm miniconda.sh \
    && conda clean -afy \
    && find ${CONDA_DIR} -follow -type f -name '*.a' -delete \
    && find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete

RUN echo "Creating default env." \
    && conda create --name ${CONDA_ENV} python=${PYTHON_VERSION} uvicorn gunicorn \
    && conda clean -yaf \
    && find ${CONDA_DIR} -follow -type f -name '*.a' -delete \
    && find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete \
    && find ${CONDA_DIR} -follow -type f -name '*.js.map' -delete

RUN echo "Setup conda init on startup." \
    && echo ". ${CONDA_DIR}/etc/profile.d/conda.sh" >> ~/.profile \
    && echo "conda activate ${CONDA_ENV}" >> ~/.profile

COPY condarc.yml /srv/condarc.yml

RUN echo "Copying configuration files..." \
    && mv /srv/condarc.yml ${CONDA_DIR}/.condarc

COPY ./start.sh /start.sh
RUN chmod +x /start.sh

COPY ./gunicorn_conf.py /gunicorn_conf.py

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY ./start-reload.sh /start-reload.sh
RUN chmod +x /start-reload.sh

COPY ./app /app
WORKDIR /app/

ENV PYTHONPATH=/app

EXPOSE 80

ENTRYPOINT [ "/entrypoint.sh" ]
# Run the start script, it will check for an /app/prestart.sh script (e.g. for migrations)
# And then will start Gunicorn with Uvicorn
CMD ["/start.sh"]