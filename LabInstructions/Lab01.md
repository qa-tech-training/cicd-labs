# Lab CICD01 - Automating Terraform Activities

## Objective
Configure a Jenkins Pipeline to provision resources using Terraform

## Outcomes
By the end of this lab, you will have:
* Created a Jenkins pipeline definition
* Configured a Jenkins job to respond to webhooks
* Configured Jenkins credentials

## High-Level Steps
* Set up a new repository with a Jenkinsfile and terraform config
* Confgure Jenkins with access to google credentials
* Configure and build a Jenkins pipeline project
* Configure a webhook from GitHub to Jenkins

## Detailed Steps
### Create a Github repository 
On GitHub, create a new repository. Name it however you wish, leave it as public and check the option to add a README. Then click on Create repository.
Once the repository is created, click on Add > create new file. In the editor that opens, paste in the contents of the Jenkinsfile from the lab01 directory:
```groovy
pipeline {
    agent any
    environment {
        TF_VAR_gcp_project = "qwiklabs-gcp-XX-XXXXXXXXXXXX" // replace with your project ID ...
    }
    stages {
        stage('Terraform Init') {
            steps {
                withCredentials([file(credentialsId: 'gcp-svc-acct', variable: 'GOOGLE_CLOUD_KEYFILE_JSON')]) {
                    sh '''
                    export GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_CLOUD_KEYFILE_JSON
                    terraform init
                    '''
                }
            }
        }
        stage('Terraform Plan') {
            steps {
                withCredentials([file(credentialsId: 'gcp-svc-acct', variable: 'GOOGLE_CLOUD_KEYFILE_JSON')]) {
                    sh '''
                    export GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_CLOUD_KEYFILE_JSON
                    terraform plan
                    '''
                }
            }
        }
        stage('Terraform Apply') {
            steps {
                withCredentials([file(credentialsId: 'gcp-svc-acct', variable: 'GOOGLE_CLOUD_KEYFILE_JSON')]) {
                    sh '''
                    export GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_CLOUD_KEYFILE_JSON
                    terraform apply -auto-approve
                    '''
                }
            }
        }
    }
}
```
changing the TF_VAR_gcp_project and TF_VAR_bucket environment variables to match your qwiklabs project ID and bucket ID. Name the new file 'Jenkinsfile', and click on commit changes.  
Once you have committed the Jenkinsfile, click Add > create new file again.  
Add the contents of lab01/main.tf to a new file. Edit line 10 with your bucket ID from lab00. 
Name the file main.tf and commit changes. You now have a repository containing a simple terraform configuration and a Jenkins pipeline definition.
 
### Add Google Cloud Credentials to Jenkins 
In order to use Terraform on Jenkins to interact with Google Cloud, we must supply it with credentials to use, typically in the form of a service account json key file.  
1. In your Google Cloud console, navigate to IAM & Admin > Service Accounts. 
2. Select the Actions menu against your Qwiklabs service account and click 'Manage Keys'
3. Select ADD KEY, and create a new key, of type json.
4. Return to the Jenkins dashboard and navigate to Manage Jenkins (the cog wheel in the top right)
5. select 'credentials' under the security section. 
6. On the breadcrumb menu, click on the Credentials dropdown and select System. 
7. Click on "Global credentials (unrestricted)"
8. Click on "Add Credentials" 
9. For Kind, choose 'Secret File'
10. select Choose file, browse to your downloads and upload the json file you previously downloaded
11. For the ID, enter gcp-svc-acct (this is the ID being referenced in the Jenkinsfile)
12. Finally, click "Create" 

### Configure Pipeline Job 
1. Select  " + New Item"  from the Jenkins dashboard 
2. Enter "Terraform Pipeline" as the item name 
3. Select "Pipeline" as the item type 
4. Click "OK" 
5. On the General page displayed next, scroll down to the Pipeline section. Use the dropdown list to change the Definition from "Pipeline script" to "Pipeline script from SCM"
6. Select "Git" from the SCM dropdown list 
7. In the Repository URL: Enter your Github repository URL
8. In "Branches to build," "Branch Specifier;" change from */master to */main 
9. Click "Save" 
10. Click "Build Now"

### Verify pipeline run and explore Jenkins 
1. In Jenkins, return to the Dashboard. A record of the pipeline will be displayed showing run success and failure. Refresh the page until a result of the pipeline run is displayed 
2. Select the drop-down menu against #1 and choose Pipeline Overview.. 
3. The stages of the pipeline are shown, with ticks (or crosses) indicating success or failure at that stage… 
4. Spend a little time exploring the Jenkins interface, using the bread-crumb menu to navigate around, and finally return to the main Dashboard… 
5. In the Google Cloud, navigate to the VPC service and verify the existence of your new 
network.

### Updating the transformation pipeline 
Now that we have the pipeline set up, in principle a team of people could then collaborate on this codebase, and allow Jenkins to manage the use of Terraform without having to manually run terraform init/plan/apply.  
This would, however, necessitate a different approach to triggering the pipeline - nobody wants to be the person whose full-time job it is to watch GitHub for changes and click 'build now' every time they see one. Instead, we will set up a _webhook_ - a notification that GitHub can send to Jenkins to inform Jenkins of the latest changes, which Jenkins can then automatically checkout and build.
1. Return to your Github repository overview
2. Click on the 'settings' tab for the repository, and find the 'webhooks' option in the side menu
3. Click on 'Add Webhook', and reauthenticate if prompted
4. Configure the webhook as follows:
    * payload URL: http://<Jenkins_IP>:8080/github-webhook/ (note: the trailing / on this URL is significant - don't miss it out)
    * content type: application/json
    * secret: leave blank for now
5. Leaving other settings as their defaults, click 'Add webhook'

So far we have configured GitHub to notify Jenkins every time there is a change to the repo. We still have not, however, indicated that Jenkins should care about these notifications.

10. In Jenkins, configure the pipeline by first selecting it on the main dashboard and then choosing the "Configure" option
11.  Scroll down to the Build Triggers section, select "Github hook trigger for GITScm polling" and click on Save
12. Return to the GitHub repository
13. Open main.tf for editing
14. Change the name of the VPC to be created. This will cause the original VPC to be deleted and a new one to be created. Commit this change.. 
15. Switch to Jenkins and observe that a build should have started automatically
15. The build Executor Status will show the progress of the run.. 
16. Click to the right of the run number and from the drop-down, select Console Output 
17. Scroll down to confirm the delete/recreate operation was successful.. 
18. Switch to your cloud console and verify the creation of the new VPC 

### Configure Destroy Pipeline Job 
1. Select  " + New Item"  from the Jenkins dashboard 
2. Enter "Terraform Pipeline Destroy" as the item name 
3. Select "Pipeline" as the item type 
4. Click "OK" 
5. On the configuration page, scroll down to the Pipeline section. This time, leave the setting as "Pipeline script". In the editor in Jenkins, add the contents from lab01/destroy/Jenkinsfile, changing the environment variables appropriately 
6. Save the configuration and build the pipeline 
7. This Jenkinsfile mandates that approval must be granted for the deletion to 
proceed.  
8. Click on the pipeline and under Builds, select the running Terraform Pipeline Destroy job and select Console Output.. 
9.  The run is waiting for approval to continue. Click on 'Yes, Destroy' to confirm the deletion 
10. The destruction should now proceed. Switch to the console to verify the deletion of your VPC 

#### Rationale for the destroy job
There are some differences in the way we have configured this second pipeline. They are not accidental. The use of 'pipeline script' instead of 'pipeline script from SCM' means that this job will NOT be automatically triggered by the existing webhook. This means that you can safely make changes to the source repo and have terraform create and update resources, and only tear everything down when you manually instruct Jenkins to do so.  
This Jenkins pipeline also includes an extra stage to checkout the repository. This was not necessary in the previous Jenkinsfile as Jenkins will check the repository out anyway in order to read the Jenkinsfile. But as this job is not reading the Jenkins pipeline from source control, we need to explicitly checkout the repository.  
This pipeline also uses an imput gate to pause execution and wait for approval. This allows us to review the actions that terraform intends to take (as output by the `terraform plan -destroy` step) and either confirm that we definitely intend to destroy everything, or bail out and abort the pipeline.