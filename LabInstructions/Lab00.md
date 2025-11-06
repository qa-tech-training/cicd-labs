# Lab CICD00 - Environment Setup

## Objective
Launch the lab environment and configure required resources

## Steps
### Start the Lab
Log into your [qwiklabs](https://qa.qwiklabs.com) account, and click on the classroom tile. Click into the lab, and click the 'Start Lab' button. Once the lab has started, right click the 'console' button and click 'open in incognito/inprivate window'.

### Setup the Environment
Once logged into the cloud console, click the cloud shell icon in the top right. Wait for cloud shell to start, then open the cloud IDE editor as well. Pop the IDE out into a separate window so that you can navigate back and forth between the IDE and the console.

In a new terminal session in the IDE window, clone the lab files:
```bash
git clone --recurse-submodules https://github.com/qa-tech-training/cicd-labs.git
```
Open the explorer pane in the editor and ensure you can see the newly cloned files.

### Edit GCE Metadata
These labs will require SSH access to VMs using self-managed SSH keys. By default, the compute engine in the qwiklabs projects has _oslogin_ enabled, which allows GCP to manage SSH access to VMs via IAM credentials. This will, however, block SSH using self-managed SSH keys, so we will need to disable it.  
In your cloud shell terminal, run the following:
```bash
gcloud compute project-info add-metadata --metadata=enable-oslogin=false
```

### Install Ansible
We will need access to ansible on the cloudshell instance in order to complete subsequent setup steps. A script to do this has been provided for the sake of convenience. Change directory into the lab00 folder, and run the script:
```bash
cd ~/cicd-labs/lab00
./install_ansible.sh
```

### Setup Jenkins Server
We will need a Jenkins server to complete todays labs. We will deploy and configure this using Terraform and Ansible. Still in the lab00 directory, run the following:
```bash
export TF_VAR_gcp_project=<qwiklabs project id>
echo !! | tee -a ~/.bashrc
export TF_VAR_bucket=tf-remote-state-$USER-$RANDOM-$RANDOM
echo "export TF_VAR_bucket=$TF_VAR_bucket" | tee -a ~/.bashrc
gcloud storage buckets create gs://$TF_VAR_bucket --location=europe-west1
ansible 127.0.0.1 -m template -a "src=$(pwd)/main.tftemp dest=$(pwd)/main.tf" -e "bucket=$TF_VAR_bucket"
ansible 127.0.0.1 -m template -a "src=$(pwd)/inventory_template.yml dest=$(pwd)/inventory.gcp_compute.yml" -e "project_id=$TF_VAR_gcp_project"
ssh-keygen -t ed25519 -f ./ansible_key -q
terraform init
terraform apply -auto-approve
ansible-playbook -i inventory.gcp_compute.yml playbook.yml
cat outputs
```

#### Setup Process Explained
By this point, you should be familiar with many of the moving parts involved in the above setup process, but let's break it down:
```bash
export TF_VAR_gcp_project=<qwiklabs project id>
```
This step exports the qwiklabs project as an environment variable. By prefixing the variable name with `TF_VAR_`, we also allow Terraform to automatically resolve this variable later on
```bash
echo !! | tee -a ~/.bashrc
```
This step echoes the last command (the variable export), and pipes the echo output to `tee`, which writes it to your .bashrc file, meaning that the variable will be set every time you start a terminal session
```bash
export TF_VAR_bucket=tf-remote-state-$USER-$RANDOM-$RANDOM
echo "export TF_VAR_bucket=$TF_VAR_bucket" | tee -a ~/.bashrc
gcloud storage buckets create gs://$TF_VAR_bucket --location=europe-west1
```
This step creates another environment variable storing a randomly generated bucket ID, and again adds this export to your bashrc, before creating the cloud storage bucket which terraform will use as its' state backend.
```bash
ansible 127.0.0.1 -m template -a "src=$(pwd)/main.tftemp dest=$(pwd)/main.tf" -e "bucket=$TF_VAR_bucket"
ansible 127.0.0.1 -m template -a "src=$(pwd)/inventory_template.yml dest=$(pwd)/inventory.gcp_compute.yml" -e "project_id=$TF_VAR_gcp_project"
```
This step uses ansible to template the project id and bucket into the dynamic inventory file and the terraform configuration.
```bash
ssh-keygen -t ed25519 -f ./ansible_key -q
```
Generate a new SSH key pair, which Terraform will inject into instance metadata, and which ansible can then use to connect to the VMs
```bash
terraform init
terraform apply -auto-approve
```
Install required Terraform providers, and apply the configuration defined by `main.tf` - one VM instance, on the default network, with a firewall allowing access on ports 22 (for SSH) and 8080 (for Jenkins itself)
```bash
ansible-playbook -i inventory.gcp_compute.yml playbook.yml
```
Run the provided ansible playbook against the hosts identified by the dynamic inventory we templated earlier. The provided ansible playbook does the following things:
* installs some key dependencies for the rest of the installation
* installs Terraform on the Jenkins server
* adds the ansible repository and installs ansible on the Jenkins server
* adds the Jenkins package repository as a new package source, with corresponding public key for signature verification
* installs the Jenkins software and starts the service
* retrieves and writes out the automatically generated initial admin password, as well as the Jenkins server IP, to a file in the working directory
```bash
cat outputs
```
This step displays the information you need to continue with the configuration

### Complete Initial Jenkins Configuration
1. In a new browser tab, navigate to the URL displayed in the output of the last command. You should see a screen which says 'unlock jenkins'. 
2. In the input field, enter the initial admin password.  
3. On the next screen, choose 'install suggested plugins' and wait for the plugins to install.  
4. On the next screen, create the first admin user with the following details:
    * username: jenkinsadmin
    * password: JenkinsP@ssw0rd!!
    * full name: Jenkins Admin
    * email: admin@jenkins.org
5. Finally, on the URL configuration screen, click 'save and finish', then 'start using jenkins'. You will be redirected to the Jenkins dashboard. We will explore some of the key areas of jenkins in the coming labs.