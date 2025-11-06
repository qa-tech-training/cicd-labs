# Lab CICD02 - Continuous Delivery With Ansible and Terraform

## Objective
To implement a CD pipeline which will automate the deployment of a sample website

## Outcomes
By the end of this lab, you will have:
* Created a Jenkins pipeline which uses Terraform and Ansible to automate a deployment
* Configured a Webhook to automatically trigger builds on code changes

## High-Level Steps
* Fork the starter repo
* Add a Jenkinsfile which defines a continuous delivery pipeline
* Configure Jenkins to execute said pipeline on a webhook trigger

## Detailed Steps

### Fork the Starter Repo
1. Sign into your [github](https://github.com) account if you are not already signed in. 
2. Once you are logged in, navigate to the [starter repo](https://github.com/qa-tech-training/cicd02-starter), and click the 'fork' button in the top right corner.
```
NOTE: when forking the repository, make sure to uncheck 'copy the main branch only', as we will need both branches for this activity.
```
3. Wait a few seconds until the fork is complete.

#### Understanding the Repo Layout
This starter repo is derived from the same sample website codebase you have already worked with, however it is structured slightly differently. The repo has two branches: a `main` branch containing the website source plus ansible and terraform files, and a `deploy` branch containing just the website source. This is one commonly-used git branching strategy, handy for keeping release-ready content independent of development/build activities. 

### Add a Jenkinsfile
In GitHub, add a new file to your repository. Name it `Jenkinsfile` (note the capitalisation - this is important). Copy the contents from lab02/Jenkinsfile into it. Make the following changes to the environment variables:
* TF_VAR_gcp_project: replace the placeholder value with your qwiklabs project ID
* TF_VAR_bucket: replace the placeholder value with your bucket ID
* REPOSITORY: fill in your GitHub username in the URL
Once you have made these changes, commit the file.

### Set Jenkins Credentials
This pipeline can re-use the serviceaccount key file from the previous lab, so this credential is fine. As we are using Ansible in this pipeline we will also need an SSH key:
1. In cloudshell, generate a new key pair:
```bash
cd ~
ssh-keygen -t ed25519 -f ./jenkinskey -q
```
2. In the explorer, right-click the new `jenkinskey` file, and download it. Open the downloaded file in notepad
3. In Jenkins, navigate to Manage Jenkins > Credentials > System > Global credentials
4. Create a new credential, of type 'SSH username with private key':
    * for the username, enter 'ansible'
    * for the key material click add > enter directly, then copy and paste the key data from the open notepad
    * set the credential ID to be 'SSH_KEY'

### Configure A Project
1. Return to the Jenkins dashboard and click 'New Item'
2. Name the project 'jenkins-tf-ansible', and select a type of 'Pipeline'
3. In the build triggers section of the configuration, check 'GitHub Hook Trigger for GitSCM Polling'
4. In the Pipeline section of the configuration, and change 'pipeline script' to 'pipeline script from SCM'. Configure the following settings:
    * SCM: git
    * repository: your repo URL
    * branch specifier: **/main
    * script path: Jenkinsfile
5. Save the configuration

### Build the Project
1. On the project overview, click 'Build Now' to trigger a manual build. The job will take several minutes to complete. While you are waiting, review the pipeline [explanation](#pipeline-explanation) below for a better understanding of what is happening.
2. Once the execution is complete, navigate to the compute engine overview and confirm the creation of three instances.
3. In a new browser tab, navigate to the External IP of the proxy server - you should see the same sample website from yesterday's lab, now deployed automatically through a Jenkins pipeline

### Setup a Webhook
1. Set up a webhook on your GitHub repo - refer to the relevant step of the previous lab if you need guidance on how to do so.
2. Once the webhook is configured, experiment with changing the number of appservers via the `count` parameter in main.tf. Any change should automatically trigger a new pipeline build which will deploy and configure any additional servers required.


#### Pipeline Explanation
The pipeline begins, after checking out the repository, by using the SSH private key we saved as a credential to reconstruct the corresponding public key. Terraform will need this to be available so that it can be injected into the instance metadata. The pipeline then performs a terraform init, plan and apply to build the infrastructure required.  
Once the infrastructure is provisioned, the pipeline switches into the ansible directory. It uses the ansible template module to inject the correct project ID into the dynamic inventory, then executes the playbook against this inventory. The playbook does much the same as it did in lab04 yesterday, with the added behaviour of only checking out the 'deploy' branch of the repository onto the appserver instances - recall that the deploy branch contains _only_ the release-ready website source, so this avoids unnecessarily cloning the ansible/terraform code onto the servers.