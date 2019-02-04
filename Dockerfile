FROM dankempster/raspbian-stretch-ansible:0.1
LABEL maintainer="Dan Kempster"

ENV DEBIAN_FRONTEND noninteractive

# Install dependencies.
# RUN mkdir -p /usr/lib/jvm/java-8-openjdk-armhf/jre/lib/arm
# RUN ln -s /usr/lib/jvm/java-8-openjdk-armhf/jre/lib/arm/client /usr/lib/jvm/java-8-openjdk-armhf/jre/lib/arm/server
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       software-properties-common \
       curl \
       dirmngr \
       gnupg \
       apt-transport-https \
       openjdk-8-jdk \
    && rm -rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && apt-get clean

# Install Jenkins
RUN apt-key adv --fetch-keys https://pkg.jenkins.io/debian/jenkins.io.key \
    && echo 'deb https://pkg.jenkins.io/debian binary/' > /etc/apt/sources.list.d/jenkins.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends jenkins \
    && rm -rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && apt-get clean \
    && mkdir -p /var/run/jenkins \
    && update-rc.d jenkins defaults \
    && sudo systemctl enable jenkins.service

COPY basic-security.groovy /var/lib/jenkins/init.groovy.d/basic-security.groovy
COPY jenkins-default /etc/default/jenkins
COPY jenkins.systemd /etc/systemd/system/multi-user.target.wants/jenkins.service
COPY locale /etc/default/locale

RUN sudo systemctl enable jenkins.service \
    && chmod 0775 /var/lib/jenkins/init.groovy.d/basic-security.groovy \
    && chown jenkins:jenkins /var/lib/jenkins/init.groovy.d/basic-security.groovy \
    && echo "\nKillExcludeUsers=root jenkins\n" > /etc/systemd/logind.conf
