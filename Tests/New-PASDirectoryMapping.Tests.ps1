#Get Current Directory
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path

#Get Function Name
$FunctionName = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -Replace ".Tests.ps1"

#Assume ModuleName from Repository Root folder
$ModuleName = Split-Path (Split-Path $Here -Parent) -Leaf

#Resolve Path to Module Directory
$ModulePath = Resolve-Path "$Here\..\$ModuleName"

#Define Path to Module Manifest
$ManifestPath = Join-Path "$ModulePath" "$ModuleName.psd1"

if( -not (Get-Module -Name $ModuleName -All)) {

	Import-Module -Name "$ManifestPath" -Force -ErrorAction Stop

}

BeforeAll {

	$Script:RequestBody = $null

}

AfterAll {

	$Script:RequestBody = $null

}

Describe $FunctionName {

	InModuleScope $ModuleName {

		Mock Invoke-PASRestMethod -MockWith {
			[PSCustomObject]@{"Prop1" = "Val1"; "Prop2" = "Val2"}
		}

		$InputObj = [pscustomobject]@{
			"sessionToken"          = @{"Authorization" = "P_AuthValue"}
			"WebSession"            = New-Object Microsoft.PowerShell.Commands.WebRequestSession
			"BaseURI"               = "https://P_URI"
			"PVWAAppName"           = "P_App"
			"DirectoryName"         = "SomeDirectory"
			"MappingName"           = "SomeMapping"
			"LDAPBranch"            = "SomeBranch"
			"DomainGroups"          = "SomeGroup"
			"DirectoryMappingOrder" = 0

		}

		Context "Mandatory Parameters" {

			$Parameters = @{Parameter = 'BaseURI'},
			@{Parameter = 'SessionToken'},
			@{Parameter = 'DirectoryName'},
			@{Parameter = 'MappingName'},
			@{Parameter = 'LDAPBranch'},
			@{Parameter = 'DomainGroups'}

			It "specifies parameter <Parameter> as mandatory" -TestCases $Parameters {

				param($Parameter)

				(Get-Command New-PASDirectoryMapping).Parameters["$Parameter"].Attributes.Mandatory | Should Be $true

			}

		}

		$response = $InputObj | New-PASDirectoryMapping -RestoreAllSafes -BackupAllSafes

		Context "Input" {

			It "sends request" {

				Assert-MockCalled Invoke-PASRestMethod -Times 1 -Exactly -Scope Describe

			}

			It "sends request to expected endpoint" {

				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$URI -eq "$($InputObj.BaseURI)/$($InputObj.PVWAAppName)/api/Configuration/LDAP/Directories/SomeDirectory/Mappings"

				} -Times 1 -Exactly -Scope Describe

			}

			It "uses expected method" {

				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {$Method -match 'POST' } -Times 1 -Exactly -Scope Describe

			}

			It "sends request with expected body" {

				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$Script:RequestBody = $Body | ConvertFrom-Json

					($Script:RequestBody) -ne $null

				} -Times 1 -Exactly -Scope Describe

			}

			It "has a request body with expected number of properties" {

				($Script:RequestBody | Get-Member -MemberType NoteProperty).length | Should Be 5

			}

			It "sends expected MappingAuthorizations enum integer in request" {

				$Script:RequestBody.MappingAuthorizations | Should Be 1536

			}

			It "throws error if version requirement not met" {
				{$InputObj | New-PASDirectoryMapping -ExternalVersion "1.0"} | Should Throw
			}

		}

		Context "Output" {

			it "provides output" {

				$response | Should not BeNullOrEmpty

			}

			It "has output with expected number of properties" {

				($response | Get-Member -MemberType NoteProperty).length | Should Be 7

			}

			it "outputs object with expected typename" {

				$response | get-member | select-object -expandproperty typename -Unique | Should Be psPAS.CyberArk.Vault.Directory.Mapping

			}

			$DefaultProps = @{Property = 'sessionToken'},
			@{Property = 'WebSession'},
			@{Property = 'BaseURI'},
			@{Property = 'PVWAAppName'},
			@{Property = 'ExternalVersion'}

			It "returns default property <Property> in response" -TestCases $DefaultProps {
				param($Property)

				$response.$Property | Should Not BeNullOrEmpty

			}

		}

	}

}