FROM ruby:2.6.5

LABEL maintainer="malston@pivotal.io"

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl vim && \
    apt-get clean && \
    rm -rf /var/cache /var/lib/apt/lists /tmp /var/tmp

RUN gem install cf-uaac

ARG pivnet_token
ENV PIVNET_TOKEN $pivnet_token

ARG pks_version
ENV PKS_VERSION ${pks_version:-1.8.1}

ARG pivnet_version
ENV PIVNET_VERSION ${pivnet_version:-2.0.1}

ARG jq_version
ENV JQ_VERSION ${jq_version:-1.6}

ARG credhub_version
ENV CREDHUB_VERSION ${credhub_version:-2.7.0}

ARG bosh_version
ENV BOSH_VERSION ${bosh_version:-6.2.1}

ARG om_version
ENV OM_VERSION ${om_version:-4.6.0}

ARG helm_version
ENV HELM_VERSION ${helm_version:-3.1.2}

ARG fly_version
ENV FLY_VERSION ${fly_version:-6.3.0}

ARG opsman_ssh_key

WORKDIR /tmp

ADD https://github.com/stedolan/jq/releases/download/jq-$JQ_VERSION/jq-linux64 .
RUN chmod +x jq-linux64 && mv jq-linux64 /usr/bin/jq

ADD https://github.com/pivotal-cf/pivnet-cli/releases/download/v$PIVNET_VERSION/pivnet-linux-amd64-$PIVNET_VERSION .
RUN chmod +x pivnet-linux-amd64-$PIVNET_VERSION && mv pivnet-linux-amd64-$PIVNET_VERSION /usr/bin/pivnet

RUN pivnet login --api-token $PIVNET_TOKEN

RUN pivnet download-product-files -p pivotal-container-service -r $PKS_VERSION -g "pks-linux-amd64*"
RUN pivnet download-product-files -p pivotal-container-service -r $PKS_VERSION -g "kubectl-linux-amd64*"

RUN chmod +x pks* && mv pks-linux-* /usr/local/bin/pks
RUN chmod +x kubectl-linux-* && mv kubectl* /usr/local/bin/kubectl

ADD https://github.com/cloudfoundry-incubator/credhub-cli/releases/download/${CREDHUB_VERSION}/credhub-linux-${CREDHUB_VERSION}.tgz .
RUN tar -xvf credhub-linux-${CREDHUB_VERSION}.tgz && rm credhub-linux-${CREDHUB_VERSION}.tgz && chmod +x credhub && mv credhub /usr/bin/credhub

ADD https://github.com/cloudfoundry/bosh-cli/releases/download/v${BOSH_VERSION}/bosh-cli-${BOSH_VERSION}-linux-amd64 .
RUN mv bosh-cli-${BOSH_VERSION}-linux-amd64 bosh && chmod +x bosh && mv bosh /usr/bin/bosh

ADD https://github.com/pivotal-cf/om/releases/download/${OM_VERSION}/om-linux-${OM_VERSION} .
RUN mv om-linux-${OM_VERSION} om && chmod +x om && mv om /usr/bin/om

ADD https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz .
RUN tar -xvf helm-v${HELM_VERSION}-linux-amd64.tar.gz --strip=1 -C /tmp && rm helm-v${HELM_VERSION}-linux-amd64.tar.gz && chmod +x /tmp/helm && mv /tmp/helm /usr/bin/helm

ADD https://github.com/concourse/concourse/releases/download/v${FLY_VERSION}/fly-${FLY_VERSION}-linux-amd64.tgz .
RUN tar -xvf fly-${FLY_VERSION}-linux-amd64.tgz && rm fly-${FLY_VERSION}-linux-amd64.tgz && chmod +x fly && mv fly /usr/bin/fly

RUN mkdir -p /root/.ssh && \
    chmod 0700 /root/.ssh

RUN echo "$opsman_ssh_key" > /root/.ssh/id_rsa && \
    chmod 600 /root/.ssh/id_rsa
