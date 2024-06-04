<#
This PowerShell script re-creates the example Certificate Authority (CA) for the tls-exercises.

It creates the following:
    I. One "root" Certificate Authority
    II. One "intermediate" Certificate Authority
    III. Multiple end entity certificates
        A. Server
        B. Client
        C. Imposter Server
#>

##############################################################################
# Setup
##############################################################################

# Go to this script's location
$script_dir = Split-Path $Script:MyInvocation.MyCommand.Path -Parent
Set-Location $script_dir

$openssl = Join-Path -Path $script_dir -ChildPath "..\..\OpenSSL\bin\openssl.exe"
$timestamp = Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }
$ca_folder = 'ca'
$backup_folder_name = $ca_folder + '.' + $timestamp

# Backup the existing CA using timestamp
# Copy-Item -Path $ca_folder -Destination $backup_folder_name -Recurse

# Declare Config files
$default_file_serial = 'serial'
$default_file_openssl = 'openssl.cfg'
$default_file_pass1 = 'pass1.txt'
$default_file_pass2 = 'pass2.txt'

# Clear the CA folder and its subfolders, except for config files
Push-Location $ca_folder
@( '*.pem', '*.cer') |
ForEach-Object {
    Get-ChildItem $_ -Recurse | Remove-Item
}

# Set serial to default value
$default_value_serial = '1000'
Get-ChildItem -Recurse -Path $default_file_serial | Set-Content -Value $default_value_serial

# Set index.txt to empty
$default_value_index = [string]::Empty
Get-ChildItem -Recurse -Path $default_file_index | Set-Content -Value $default_value_index -NoNewline

$process_args = @{
    WindowStyle = "Hidden"
    Wait = $true
    RedirectStandardOutput = "log_out.txt"
    RedirectStandardError = "log_err.txt"
}

##############################################################################
# I. Generate the Root Certificate Authority
##############################################################################

$root_ca_prv_key = 'ca.key.pem'
$root_ca_cert = 'ca.cert.pem'

# Generate its key pair
$my_args = @{
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "genrsa",
                    "-aes256",
                    "-quiet",
                    "-out $(Join-Path 'private' $root_ca_prv_key)",
                    "-passout file:$default_file_pass1",
                    "4096"
                    )
}
Start-Process @process_args @my_args

# Sign its identity certificate with its own private key
$my_args = @{
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "req",
                    "-config $default_file_openssl",
                    "-key $(Join-Path 'private' $root_ca_prv_key)",
                    "-new",
                    "-x509",
                    "-days 7300",
                    "-sha256",
                    "-extensions v3_ca",
                    '-subj "/C=GB/ST=England/O=Expert TLS/OU=IT Training/CN=Expert TLS Root CA"',
                    "-out $(Join-Path 'certs' $root_ca_cert)",
                    "-passin file:$default_file_pass1",
                    "-passout file:$default_file_pass2"
                    )
}
Start-Process @process_args @my_args

# Examine the certificate
$my_args = @{
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "x509",
                    "-noout",
                    "-text",
                    "-in $(Join-Path 'certs' $root_ca_cert)"
                    )
}
Start-Process @process_args @my_args

##############################################################################
# II. Generate the intermediate Certificate Authority
##############################################################################

$intmdt_ca_prv_key = 'intermediate.key.pem'
$intmdt_ca_csr = 'intermediate.csr.pem'
$intmdt_ca_cert = 'intermediate.cert.pem'

# Generate its key pair
$my_args = @{
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "genrsa",
                    "-aes256",
                    "-out $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'private')) -ChildPath $intmdt_ca_prv_key)",
                    "-passout file:$default_file_pass1",
                    "4096"
                    )
}
Start-Process @process_args @my_args

# Create a certificate signing request (CSR) to create the intermediate CA identity
$my_args = @{
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "req",
                    "-config $(Join-Path -Path 'intermediate' -ChildPath $default_file_openssl)",
                    "-new",
                    "-sha256",
                    '-subj "/C=GB/ST=England/O=Expert TLS/OU=IT Training/CN=Expert TLS Int CA"',
                    "-key $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'private')) -ChildPath $intmdt_ca_prv_key)",
                    "-out $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'csr')) -ChildPath $intmdt_ca_csr)",
                    "-passin file:$default_file_pass1",
                    "-passout file:$default_file_pass2"
                    )
}
Start-Process @process_args @my_args

# Sign the CSR for the Intermediate CA using the Root CA
$my_args = @{
    RedirectStandardInput = "sign_prompt.txt"
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "ca",
                    "-config $default_file_openssl",
                    "-extensions v3_intermediate_ca",
                    "-days 3650",
                    "-notext",
                    "-md sha256",
                    "-quiet",
                    "-in $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'csr')) -ChildPath $intmdt_ca_csr)",
                    "-out $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'certs')) -ChildPath $intmdt_ca_cert)",
                    "-passin file:$default_file_pass1"
                    )
}
Start-Process @process_args @my_args

# Examine the certificate
$my_args = @{
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "x509",
                    "-noout",
                    "-text",
                    "-in $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'certs')) -ChildPath $intmdt_ca_cert)"
                    )
}
Start-Process @process_args @my_args

##############################################################################
#III. Generate Server certificate
##############################################################################

$server_prv_key = 'server.key.pem'
$server_csr = 'server.csr.pem'
$server_cert = 'server.cert.pem'

# Generate the server's key pair
$my_args = @{
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "genrsa",
                    "-aes256",
                    "-out $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'private')) -ChildPath $server_prv_key)",
                    "-passout file:$default_file_pass1",
                    "2048"
                    )
}
Start-Process @process_args @my_args

# Create a certificate signing request (CSR) to create the Server certificate identity
$my_args = @{
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "req",
                    "-config $(Join-Path -Path 'intermediate' -ChildPath $default_file_openssl)",
                    "-new",
                    "-sha256",
                    '-subj "/C=GB/ST=England/O=Expert TLS/OU=IT Training/CN=Expert TLS Server"',
                    "-key $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'private')) -ChildPath $server_prv_key)",
                    "-out $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'csr')) -ChildPath $server_csr)",
                    "-passin file:$default_file_pass1",
                    "-passout file:$default_file_pass2"
                    )
}
Start-Process @process_args @my_args

# Sign the CSR for the Server certificate using the Intermediate CA
$my_args = @{
    RedirectStandardInput = "sign_prompt.txt"
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "ca",
                    "-config $(Join-Path -Path 'intermediate' -ChildPath $default_file_openssl)",
                    "-extensions server_cert",
                    "-days 375",
                    "-notext",
                    "-md sha256",
                    "-quiet",
                    "-in $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'csr')) -ChildPath $server_csr)",
                    "-out $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'certs')) -ChildPath $server_cert)",
                    "-passin file:$default_file_pass1"
                    )
}
Start-Process @process_args @my_args

# Examine the certificate
$my_args = @{
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "x509",
                    "-noout",
                    "-text",
                    "-in $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'certs')) -ChildPath $server_cert)"
                    )
}
Start-Process @process_args @my_args

##############################################################################
#IV. Generate Client certificate
##############################################################################

$client_prv_key = 'client.key.pem'
$client_csr = 'client.csr.pem'
$client_cert = 'client.cert.pem'

# Generate the client's key pair
$my_args = @{
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "genrsa",
                    "-aes256",
                    "-out $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'private')) -ChildPath $client_prv_key)",
                    "-passout file:$default_file_pass1",
                    "2048"
                    )
}
Start-Process @process_args @my_args

# Create a certificate signing request (CSR) to create the Client certificate identity
$my_args = @{
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "req",
                    "-config $(Join-Path -Path 'intermediate' -ChildPath $default_file_openssl)",
                    "-new",
                    "-sha256",
                    '-subj "/C=GB/ST=England/O=Expert TLS/OU=IT Training/CN=Expert TLS Client"',
                    "-key $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'private')) -ChildPath $client_prv_key)",
                    "-out $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'csr')) -ChildPath $client_csr)",
                    "-passin file:$default_file_pass1",
                    "-passout file:$default_file_pass2"
                    )
}
Start-Process @process_args @my_args

# Sign the CSR for the Client certificate using the Intermediate CA
$my_args = @{
    RedirectStandardInput = "sign_prompt.txt"
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "ca",
                    "-config $(Join-Path -Path 'intermediate' -ChildPath $default_file_openssl)",
                    "-extensions usr_cert",
                    "-days 375",
                    "-notext",
                    "-md sha256",
                    "-quiet",
                    "-in $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'csr')) -ChildPath $client_csr)",
                    "-out $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'certs')) -ChildPath $client_cert)",
                    "-passin file:$default_file_pass1"
                    )
}
Start-Process @process_args @my_args

# Examine the certificate
$my_args = @{
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "x509",
                    "-noout",
                    "-text",
                    "-in $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'certs')) -ChildPath $server_cert)"
                    )
}
Start-Process @process_args @my_args

##############################################################################
#III. Generate Imposter Server certificate
##############################################################################

$alt_server_prv_key = 'server.alt.key.pem'
$alt_server_csr = 'server.alt.csr.pem'
$alt_server_cert = 'server.alt.cert.pem'

# Generate the server's key pair
$my_args = @{
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "genrsa",
                    "-aes256",
                    "-out $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'private')) -ChildPath $alt_server_prv_key)",
                    "-passout file:$default_file_pass1",
                    "2048"
                    )
}
Start-Process @process_args @my_args

# Create a certificate signing request (CSR) to create the Server certificate identity
$my_args = @{
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "req",
                    "-config $(Join-Path -Path 'intermediate' -ChildPath $default_file_openssl)",
                    "-new",
                    "-sha256",
                    '-subj "/C=GB/ST=England/O=Expert TLS/OU=IT Training/CN=Expert TLS Imposter Server"',
                    "-key $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'private')) -ChildPath $alt_server_prv_key)",
                    "-out $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'csr')) -ChildPath $alt_server_csr)",
                    "-passin file:$default_file_pass1",
                    "-passout file:$default_file_pass2"
                    )
}
Start-Process @process_args @my_args

# Sign the CSR for the Server certificate using the Intermediate CA
$my_args = @{
    RedirectStandardInput = "sign_prompt.txt"
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "ca",
                    "-config $(Join-Path -Path 'intermediate' -ChildPath $default_file_openssl)",
                    "-extensions server_cert",
                    "-days 375",
                    "-notext",
                    "-md sha256",
                    "-quiet",
                    "-in $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'csr')) -ChildPath $alt_server_csr)",
                    "-out $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'certs')) -ChildPath $alt_server_cert)",
                    "-passin file:$default_file_pass1"
                    )
}
Start-Process @process_args @my_args

# Examine the certificate
$my_args = @{
    FilePath = $openssl
    ArgumentList = [string]::Join(" ",
                    "x509",
                    "-noout",
                    "-text",
                    "-in $(Join-Path -Path ($(Join-Path -Path 'intermediate' -ChildPath 'certs')) -ChildPath $alt_server_cert)"
                    )
}
Start-Process @process_args @my_args

Pop-Location

##############################################################################
# END
##############################################################################