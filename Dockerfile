FROM public.ecr.aws/docker/library/ruby:3.3-bookworm AS base

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs=10

COPY . .

##########################################################################

FROM public.ecr.aws/docker/library/ruby:3.3-slim-bookworm

COPY --from=base /usr/local/bundle /usr/local/bundle
COPY --from=base /app /app

RUN echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/00-docker \
  && echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker \
  && apt update \
  && apt upgrade -y \
  && apt install -y \
    iproute2 \
    curl \
    jq \
    unzip \
  && curl https://bun.sh/install | bash \
  && cd /tmp \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf /tmp/* \
  && apt purge --autoremove -y \
    unzip \
  && apt clean \
  && rm -rf /var/lib/apt/lists/*

ENV BUN_INSTALL="/root/.bun"
ENV PATH="$BUN_INSTALL/bin:$PATH"

WORKDIR /app

ENV RAILS_ENV=production
RUN rails credentials:edit \
  && rake assets:precompile

HEALTHCHECK --interval=10s --timeout=3s \
  CMD curl -f -s http://localhost:3000/health/ || exit 1
EXPOSE 3000
ENTRYPOINT ["bash","/app/startup-cdk.sh"]
