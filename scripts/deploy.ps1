param (
    $cluster ,
    $namespace,
    $installFlux = $true
)

if ( -not $cluster ) {
    $cluster = "localhost"
}

if ( -not $namespace ) {
    $namespace = "wac-hospital"
}

$ProjectRoot = "${PSScriptRoot}/.."
echo "ScriptRoot is $PSScriptRoot"
echo "ProjectRoot is $ProjectRoot"

$clusterRoot = "$ProjectRoot/clusters/$cluster"

$ErrorActionPreference = "Stop"

$context = kubectl config current-context

if ((Get-Host).version.major -lt 7 ){
    Write-Host -Foreground red "PowerShell Version must be minimum of 7, please install latest version of PowerShell. Current Version is $((Get-Host).version)"
    exit -10
}
$pwsv=$((Get-Host).version)

# check if $cluster folder exists
if (-not (Test-Path -Path "$clusterRoot" -PathType Container)) {
    Write-Host -Foreground red "Cluster folder $cluster does not exist"
    exit -12
}

$banner = @"
THIS IS A FAST DEPLOYMENT SCRIPT FOR DEVELOPERS!
---

The script shall be running **only on fresh local cluster** **!
After initialization, it **uses gitops** controlled by installed flux cd controller.
To do some local fine tuning get familiarized with flux, kustomize, and kubernetes

Verify that your context is coresponding to your local development cluster:

* Your kubectl *context* is **$context**.
* You are installing *cluster* **$cluster**.
* *PowerShell* version is **$pwsv**.
"@

$banner = ($banner | ConvertFrom-MarkDown -AsVt100EncodedString)
Show-Markdown -InputObject $banner
Write-Host "$banner"
$correct = Read-Host "Are you sure to continue? (y/n)"

if ($correct -ne 'y')
{
    Write-Host -Foreground red "Exiting script due to the user selection"
    exit -1
}

# create a namespace
Write-Host -Foreground blue "Creating namespace $namespace"
kubectl create namespace $namespace
Write-Host -Foreground green "Created namespace $namespace"


Write-Host -Foreground blue "Applying repository-pat secret"
kubectl apply -f "$clusterRoot/secrets/repository-pat.yaml" -n $namespace
Write-Host -Foreground green "Created repository-pat secret in the namespace ${namespace}"

if($installFlux)
{
    Write-Host -Foreground blue "Deploying the Flux CD controller"
    # first ensure crds exists when applying the repos
    kubectl apply -k $ProjectRoot/infrastructure/fluxcd --wait

    if ($LASTEXITCODE -ne 0) {
        Write-Host -Foreground red "Failed to deploy fluxcd"
        exit -15
    }

    Write-Host -Foreground blue "Flux CD controller deployed"
}

Write-Host -Foreground blue "Deploying the cluster manifests"
kubectl apply -k $clusterRoot --wait
Write-Host -Foreground green "Bootstrapping process is done, check the status of the GitRepository and Kustomization resource in namespace ${namespace} for reconcilation updates"