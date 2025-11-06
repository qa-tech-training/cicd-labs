# Lab CICD03 - Scheduling Ansible Jobs With AWX

## Objective
Create a job in AWX to manage scheduled ansible executions

## Outcomes
By the end of this lab, you will have:
* deployed an AWX cluster
* Configured credentials in AWX
* Configured an AWX job to run scheduled maintenance activities

## High-Level Steps
* Deploy AWX
* Add an SSH key as a credential to AWX
* Create and run an AWX job

## Detailed Steps

### Deploy AWX
1. In your cloudshell, navigate to the lab03 directory
2. Initialise Terraform and apply the configuration:
```bash
cd ~/cicd-labs/lab03
ansible 127.0.0.1 -m template -a "src=$(pwd)/main.tftemp dest=$(pwd)/main.tf" -e "bucket=$TF_VAR_bucket"
terraform init
terraform apply -auto-approve
``` 
3. The init script takes several minutes to run, after which AWX will need another several minutes to fully initialise. Take the time to review the [explanation](#the-awx-init-script-explained) of what the script is actually doing
4. After waiting for several minutes, navigate to http://<awx_ip>:30080 in a new browser tab. If AWX is still configuring, wait longer.
5. Once AWX is finally ready, log in with the following credentials:
    * username: admin
    * password: ChangeMe123!
You should now see the AWX dashboard.

### Create an AWX Job
1. In the AWX dashboard, create a new organisation:
    * Click on the Organizations under Access from the left side pane
    * Click Add button to Create New Organization
    * When prompted to enter Organization Name, enter `BOAAWX`
    * Click on Save
2. Return to the AWX dashboard and select Resources > Projects > add
3. Configure the project as follows:
    * name: nginx-updates 
    * Organizations as `BOAAWX` 
    * SCM Type as "Git" 
    * repository as the URL for your repo from lab02 

### Add SSH Credentials
To be able to connect to our machines, AWX will need access to the private SSH key that corresponds to the public key used to build the infrastructure.
1. Navigate to Resources > Credentials, click 'add'
2. Configure the new credential as follows:
    * name: ansible_ssh_key
    * organization: BOAAWX
    * credential type: machine
    * username: ansible
    * SSH Private Key: paste in the same key material you gave to Jenkins earlier
    * privilege escalation method: sudo
    * privilege escalation password: leave blank
3. Save the credential

### Add an Inventory
1. Navigate to Resources > Inventory and click Add
2. Name the inventory 'webservers', and associate it to the BOAAWX organization, and save

We will keep things simple with a static inventory for now, but this could be dynamic
3. Click on Hosts
4. Add a host by clicking add. Enter the IP of one of your servers (NOT the Jenkins or AWX VMs, only the servers created by your pipeline)
5. Repeat for the other servers

### Create a Job Template
1. Navigate to Resources > Templates, and click add.
2. Configure the following:
    * NAME: update nginx
    * Description : Ensure nginx is latest version
    * JOB TYPE: Run 
    * INVENTORY: webservers
    * PROJECT: nginx-updates
    * PLAYBOOK: ansible/playbook.yml
    * CREDENTIALS: ansible_ssh_key
3. Save the template configuration, then run the job manually to test connectivity

### Create a Schedule
As with Jenkins, manually triggering job executions is not the preferred way to run AWX jobs. AWX is excellent for scheduling jobs, to be run at specific times.
1. Select your job template, edit it and select `schedules`
2. Configure the schedule so that the job runs every day at midnight. 


#### The AWX Init Script Explained
The primary distribution mechanism for AWX is as a Kubernetes operator. Detailed understanding of Kubernetes is beyond the scope of this course, but in short it is the de-facto standard orchestration platform for containerised workloads. Running AWX through Kubernetes allows for highly available, scalable deployments of the workloads needed to execute AWX jobs. To set up AWX, the init script does the following:
* installs and configures _docker_, a common container management tool
* installs *k*ubernetes-*in*-*d*ocker (KinD), a tool for running a Kubernetes cluster as a set of containers
* Creates a KinD cluster with appropriate ports mapped
* Deploys the AWX operator and associated resources into the KinD cluster
[back to instructions](#deploy-awx)