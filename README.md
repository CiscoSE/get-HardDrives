**Cisco Disk Evaluation for Field Notice FN70545**

This PowerShell script requires Cisco PowerTool. Please ensure you install this before attempting to run this script. You can obtain Cisco PowerTool from the following location:

>https://software.cisco.com/download/home/286305108/type/284574017/

***When to run this script***
This script is only intended for Cisco UCS Servers running in stand-alone mode. It will not work for server managed by UCS Manager. This script is intended to find SSD hard drives that are known to be susceptible to issues seen in Cisco Field Notice FN70545.

>https://www.cisco.com/c/en/us/support/docs/field-notices/705/fn70545.html

***Running This Script***
This script has been tested with PowerShell 5.1 and Cisco PowerTool version 2.5.3.0, though it is likely to run with other versions in the 2.4 or 2.5 range. It will work with PowerShell Core.

The PowerShell script communicates with the CIMC itself via IP, and does not interact with the operating system in any way. It makes no changes to the configuration and will not remediate any issues it finds. All servers evaluated at one time must use the same user name and password for access. 

The most common ways to run the script are as follows:

Example 1
verify-FN70545-Firmware.ps1 -CimcIPs 1.1.1.1

This will run a report on the IP or fully qualified domain name passed to -CimcIPs

Example 2
verify-FN70545-Firmware.ps1 -CimcIPs 1.1.1.1,1.1.1.2,somecimc.yourdomain.local

This will run a report on more each IP passed to -CimcIPs. Do not include spaces between IP addresses or dns names. Separate each with a comma.

Example 3
verify-FN70545-Firmware.ps1 -CSVFile ./Servers.csv

This will look for a column in the CSV file named "Server" and will run a report for each IP or resolvable name found in the Server field. An example csv file would look like this:

Server
1.1.1.1
1.1.1.2
somecimc.yourdomain.local

You can combine the -CSV and -CimcIPs switches and both will be evaluated. 

***Reports***
Reports by default are placed in the ./Reports directory. An HTML inventory report is always provided showing all CIMCs that were connected to successfully and processed. A second Impacted Disk Report is only generated if disks are found that need review. 



