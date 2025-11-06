# Lab CICD04 - Effective Credential Management

## Objective
Deploy Hashicorp Vault and use it to store credentials

## Outcomes
By the end of this lab, you will have:
* Deployed hashicorp vault in development mode
* Created a Vault secret
* Configured AWX to retrieve a secret from a vault

## High-Level Steps
* Deploy Hashicorp vault
* move SSH key into vault
* Reconfigure AWX jobs to read credentials from vault

## Detailed Steps

### Deploy Vault
1. In cloudshell, switch into the lab04 directory, and run the following to deploy a vault server:
```bash
cd ~/cicd-labs/lab04
ansible 127.0.0.1 -m template -a "src=$(pwd)/main.tftemp dest=$(pwd)/main.tf" -e "bucket=$TF_VAR_bucket"
terraform init
terraform apply -auto-approve
```
2. Make a note of the output `vault_ip` value, and also the root token that this vault installation has been deployed with: example-vault-token-1234. We will use these in the next step.

### Store a Credential
Let's store our first credential in vault. We will start by storing the private SSH key that Jenkins and AWX have been using for ansible jobs. Run the following in cloudshell:
```bash
export VAULT=<your vault IP>
export VAULT_TOKEN=example-vault-token-1234
echo "{\"data\": {\"sshkey\":\"$(cat ~/jenkinskey)\"}}" > data.json
curl \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -XPOST \
    -d@data.json \
    http://$VAULT:8200/v1/secret/data/ansible-ssh-key
```
Verify the credential creation:
```bash
curl \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    http://$VAULT:8200/v1/secret/data/ansible-ssh-key > secrets.json
cat secrets.json
```

### Configure AWX to Retrieve Credentials from Vault
1. Return to your AWX dashboard and navigate to the credentials overview.
2. Create a new credential with the following configuration:
    * type: HashiCorp Vault Secret Lookup
    * name: vault_credential
    * URL: http://<your vault server IP>:8200
    * Token: example-vault-token-1234
    * API version: v1
3. Save this credential and return to the credentials overview
4. Edit the configuration for the credential you created earlier:
    * Input sources: choose the new credential you just created
    * Input field: SSH Private Key
    * secret path: /kv/ansible-ssh-key
    * secret key: sshkey
5. Return to the job template you defined earlier and trigger a new execution, to test the connectivity with the key pulled from vault.