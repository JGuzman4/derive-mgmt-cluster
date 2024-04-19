.PHONY: vpc cluster

vpc:
	export AWS_ACCESS_KEY_ID=$$(cat ../derive-cloud-baseline/baseline/terraform.tfstate | jq -r .outputs.admin_user_access_key_id.value) ; \
	export AWS_SECRET_ACCESS_KEY=$$(cat ../derive-cloud-baseline/baseline//terraform.tfstate | jq -r .outputs.admin_user_access_key_secret.value) ; \
	cd vpc ; \
	terraform init; \
	terraform plan -var-file=env/prod.json
	#terraform apply -var-file=env/vpc/prod.json

cluster:
	export AWS_ACCESS_KEY_ID=$$(cat ../derive-cloud-baseline/baseline/terraform.tfstate | jq -r .outputs.admin_user_access_key_id.value) ; \
	export AWS_SECRET_ACCESS_KEY=$$(cat ../derive-cloud-baseline/baseline/terraform.tfstate | jq -r .outputs.admin_user_access_key_secret.value) ; \
	cd cluster ; \
	terraform init; \
	terraform plan -var-file=env/prod.json
	#terraform apply -var-file=env/cluster/prod.json

update-kubeconfig:
	aws eks update-kubeconfig --region us-west-1 --name eks-management-cluster --alias eks-management-cluster
	kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d | pbcopy
	kubectl port-forward -n argocd svc/argocd-server 8080:80
