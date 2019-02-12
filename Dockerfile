FROM dankempster/raspbian-stretch-ansible:0.1
LABEL maintainer="Dan Kempster <me@dankempster.co.uk>"

COPY locale /etc/default/locale
COPY jenkins-default /etc/default/jenkins
COPY jenkins.systemd /etc/systemd/system/multi-user.target.wants/jenkins.service

RUN echo "\nKillExcludeUsers=root jenkins\n" > /etc/systemd/logind.conf
