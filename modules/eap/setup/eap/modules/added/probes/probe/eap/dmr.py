"""
Copyright 2017 Red Hat, Inc.

Red Hat licenses this file to you under the Apache License, version
2.0 (the "License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied.  See the License for the specific language governing
permissions and limitations under the License.
"""

import os
import re

from probe.api import Status, Test
from probe.dmr import DmrProbe

class EapProbe(DmrProbe):
    """
    Basic EAP probe which uses the DMR interface to query server state. It
    defines tests for server status, server running mode, boot errors, deployment
    and datasources status.
    """

    def __init__(self):
        super(EapProbe, self).__init__(
            [
                ServerStatusTest(),
                ServerRunningModeTest(),
                BootErrorsTest(),
                DeploymentTest(),
                LoopOverNonXADatasourcesTest(),
                LoopOverXADatasourcesTest()
            ]
        )

class ServerStatusTest(Test):
    """
    Checks the status of the server.
    """

    def __init__(self):
        super(ServerStatusTest, self).__init__(
            {
                "operation": "read-attribute",
                "name": "server-state"
            }
        )

    def evaluate(self, results):
        """
        Evaluates the test:
            READY for "running"
            FAILURE if the query itself failed
            NOT_READY for all other states
        """

        if results["outcome"] != "success" and results.get("failure-description"):
            return (Status.FAILURE, "DMR query failed")
        if results["result"] == "running":
            return (Status.READY, results["result"])
        return (Status.NOT_READY, results["result"])

class ServerRunningModeTest(Test):
    """
    Checks the running mode of the server.
    """

    def __init__(self):
        super(ServerRunningModeTest, self).__init__(
            {
                "operation": "read-attribute",
                "name": "running-mode"
            }
        )

    def evaluate(self, results):
        """
        Evaluates the test:
            READY for "NORMAL"
            FAILURE if the query itself failed
            NOT_READY for all other states
        """

        if results["outcome"] != "success" and results.get("failure-description"):
            return (Status.FAILURE, "DMR query failed")
        if results["result"] == "NORMAL":
            return (Status.READY, results["result"])
        return (Status.NOT_READY, results["result"])

class BootErrorsTest(Test):
    """
    Checks the server for boot errors.
    """

    def __init__(self):
        super(BootErrorsTest, self).__init__(
            {
                "operation": "read-boot-errors",
                "address": {
                    "core-service": "management"
                }
            }
        )
        self.__disableBootErrorsCheck = os.getenv("PROBE_DISABLE_BOOT_ERRORS_CHECK", "false").lower() == "true"

    def evaluate(self, results):
        """
        Evaluates the test:
            READY if no boot errors were returned
            HARD_FAILURE if any boot errors were returned
            FAILURE if the query itself failed
        """

        if self.__disableBootErrorsCheck:
            return (Status.READY, "Boot errors check is disabled")

        if results["outcome"] != "success" and results.get("failure-description"):
            return (Status.FAILURE, "DMR query failed")

        if results.get("result"):
            errors = []
            errors.extend(results["result"])
            return (Status.HARD_FAILURE, errors)

        return (Status.READY, "No boot errors")

class DeploymentTest(Test):
    """
    Checks the state of the deployments.
    """

    def __init__(self):
        super(DeploymentTest, self).__init__(
            {
                "operation": "read-attribute",
                "address": {
                    "deployment": "*"
                },
                "name": "status"
            }
        )

    def evaluate(self, results):
        """
        Evaluates the test:
            READY if all deployments are OK
            HARD_FAILURE if any deployments FAILED
            FAILURE if the query failed or if any deployments are not OK, but not FAILED
        """

        if results["outcome"] != "success" and results.get("failure-description"):
            return (Status.FAILURE, "DMR query failed")

        if not results["result"]:
            return (Status.READY, "No deployments")

        status = set()
        messages = {}
        for result in results["result"]:
            if result["outcome"] != "success" and result.get("failure-description"):
                status.add(Status.FAILURE)
                messages[result["address"][0]["deployment"]] = "DMR query failed"
            else:
                deploymentStatus = result["result"]
                messages[result["address"][0]["deployment"]] = deploymentStatus
                if deploymentStatus == "FAILED":
                    status.add(Status.HARD_FAILURE)
                elif deploymentStatus == "OK":
                    status.add(Status.READY)
                else:
                    status.add(Status.FAILURE)

        return (min(status), messages)

class LoopOverNonXADatasourcesTest(Test):
    """
    Loops over the defined non-XA datasources and for each
    of them checks if a JDBC connection can be established.
    """

    def __init__(self):
        super(LoopOverNonXADatasourcesTest, self).__init__(
            {
                "address": {
                    "subsystem": "datasources",
                    "data-source": "*"
                },
                "name": "jndi-name",
                "operation": "read-attribute"
            }
        )

    def evaluate(self, results):
        """
        Evaluates the test:
            READY if the DMR query succeeded and the list of defined non-XA datasources is empty
            READY if the DMR query succeeded, there are some non-XA datasources defined and a JDBC
            connection test succeeded for each of them
            FAILURE if the DMR query itself failed
            FAILURE if a JDBC connection test for a particular non-XA datasource returns ambiguous (more
            than one) exit status
            FAILURE if the DMR query succeeded, the list of names of defined non-XA datasources
            was retrieved successfully, but the JDBC connection test failed for at least one
            of them
        """

        # Retrieve the names of all defined non-XA datasources
        datasourceNames = set()
        # Query failed
        if results["outcome"] != "success":
            return (Status.FAILURE, "Failed to retrieve the names of defined non-XA datasources.")
        # Query succeeded, but no non-XA datasource is defined
        if results["outcome"] == "success" and not results["result"]:
            return (Status.READY, "List of defined non-XA datasources is empty.")
        # Query succeeded
        for result in results["result"]:
            if result["outcome"] != "success":
                return (Status.FAILURE, "Failed to retrieve the names of defined non-XA datasources.")
            else:
                datasourceNames.add(result["address"][1]["data-source"])

        # For each of them, check if a JDBC connection can be established
        dsProbe = DmrProbe()
        dsLoopOutput = dict()
        for ds in datasourceNames:
            dsProbe.addTest(SingleNonXADatasourceConnectionTest(ds))
            (dsTestStatusSet, dsTestOutput) = dsProbe.execute()
            # Valid tests have just a single exit status
            if len(dsTestStatusSet) != 1:
                return (Status.FAILURE, "Ambiguous result of the SingleNonXADatasourceConnectionTest test, when checking the '" + ds + "' datasource.")
            # Datasource connection test failed
            # Return the actual exit status and output message of the test
            if Status.READY not in dsTestStatusSet:
                dsTestStatus = dsTestStatusSet.pop()
                # But from the dict containing output of all tests, filter just
                # the output message relevant to this specific test
                for key, value in dsTestOutput.items():
                    if "SingleNonXADatasourceConnectionTest" in key and ds in value:
                        dsTestOutputMessage = str(key) + ":" + str(value)
                        return (dsTestStatus, dsTestOutputMessage)
            # Datasource connection test succeeded
            # Just append the output message of the test to the overall output
            else:
                for key, value in dsTestOutput.items():
                    # But from the dict containing output messages of all tests,
                    # filter just the output message relevant to this specific test
                    if "SingleNonXADatasourceConnectionTest" in key and ds in value:
                        dsLoopOutput[key + " of '" + ds + "' datasource:"] = value

        # In the case the connection test succeeded for all non-XA datasources,
        # return success (ready status) and the overall output message
        return (Status.READY, dsLoopOutput)

class LoopOverXADatasourcesTest(Test):
    """
    Loops over the defined XA datasources and for each
    of them checks if a JDBC connection can be established.
    """

    def __init__(self):
        super(LoopOverXADatasourcesTest, self).__init__(
            {
                "address": {
                    "subsystem": "datasources",
                    "xa-data-source": "*"
                },
                "name": "jndi-name",
                "operation": "read-attribute"
            }
        )

    def evaluate(self, results):
        """
        Evaluates the test:
            READY if the DMR query succeeded and the list of defined XA datasources is empty
            READY if the DMR query succeeded, there are some XA datasources defined and the JDBC
            connection test succeeded for each of them
            FAILURE if the DMR query itself failed
            FAILURE if a JDBC connection test for a particular XA datasource returns ambiguous (more
            than one) exit status
            FAILURE if the DMR query succeeded, the list of names of defined XA datasources
            was retrieved successfully, but the JDBC connection test failed for at least one
            of them
        """

        # Retrieve the names of all defined XA datasources
        xaDatasourceNames = set()
        # Query failed
        if results["outcome"] != "success":
            return (Status.FAILURE, "Failed to retrieve the names of defined XA datasources.")
        # Query succeeded, but no XA datasource is defined
        if results["outcome"] == "success" and not results["result"]:
            return (Status.READY, "List of defined XA datasources is empty.")
        # Query succeeded
        for result in results["result"]:
            if result["outcome"] != "success":
                return (Status.FAILURE, "Failed to retrieve the names of defined XA datasources.")
            else:
                xaDatasourceNames.add(result["address"][1]["xa-data-source"])

        # For each of them, check if a JDBC connection can be established
        xadsProbe = DmrProbe()
        xadsLoopOutput = dict()
        for xads in xaDatasourceNames:
            xadsProbe.addTest(SingleXADatasourceConnectionTest(xads))
            (xadsTestStatusSet, xadsTestOutput) = xadsProbe.execute()
            # Valid tests have just a single exit status
            if len(xadsTestStatusSet) != 1:
                return (Status.FAILURE, "Ambiguous result of the SingleXADatasourceConnectionTest test, when checking the '" + xads + "' XA datasource.")
            # Datasource connection test failed
            # Return the actual exit status and output message of the test
            if Status.READY not in xadsTestStatusSet:
                xadsTestStatus = xadsTestStatusSet.pop()
                # But from the dict containing output of all tests, filter just
                # the output message relevant to this specific test
                for key, value in xadsTestOutput.items():
                    if "SingleXADatasourceConnectionTest" in key and xads in value:
                        xadsTestOutputMessage = str(key) + ":" + str(value)
                        return (xadsTestStatus, xadsTestOutputMessage)
            # Datasource connection test succeeded
            # Just append the output message of the test to the overall output
            else:
                for key, value in xadsTestOutput.items():
                    # But from the dict containing output of all tests, filter just
                    # the output message relevant to this specific test
                    if "SingleXADatasourceConnectionTest" in key and xads in value:
                        xadsLoopOutput[key + " of '" + xads + "' XA datasource:"] = value

        # In the case the connection test succeeded for all XA datasources,
        # return success (ready status) and the overall output message
        return (Status.READY, xadsLoopOutput)

class SingleNonXADatasourceConnectionTest(Test):
    """
    Given a name of a non-XA datasource, checks if a JDBC connection can be obtained.
    """

    def __init__(self, datasourceName):
        self.datasourceName = datasourceName
        super(SingleNonXADatasourceConnectionTest, self).__init__(
            {
                "address": {
                    "subsystem": "datasources",
                    "data-source": self.datasourceName
                },
                "operation": "test-connection-in-pool"
            }
        )

    def evaluate(self, results):
        """
        Evaluates the test:
            READY if DMR query succeeded and the JDBC connection test returned 'True'
            NOT_READY if DMR query succeeded, but the JDBC connection test returned anything else
            FAILURE if the DMR query itself failed
        """

        # DMR query itself succeeded
        if results["outcome"] == "success":
            # And datasource connection test returned 'True'. Return ready
            if str(results["result"][0]).lower() == "true":
                return (Status.READY, "Successfully created a JDBC connection for the '" + self.datasourceName + "' datasource.")
            # And datasource connection test returned anything else.
            # Return not ready (not failed, but e.g. might be still starting up etc.)
            else:
                return (Status.NOT_READY, "Failed to create a JDBC connection for the '" + self.datasourceName + "' datasource.")
        # DMR query failed
        else:
            # The connection test returned e.g. a failure with description like:
            # "WFLYJCA0040: failed to invoke operation: WFLYJCA0047: Connection is not valid"
            # Return failure (test failed this time, but might succeed next time)
            return (Status.FAILURE, "Failed to create a JDBC connection for the '" + self.datasourceName + "' datasource.")

class SingleXADatasourceConnectionTest(Test):
    """
    Given a name of a XA datasource, checks if a JDBC connection can be obtained.
    """

    def __init__(self, xaDatasourceName):
        self.xaDatasourceName = xaDatasourceName
        super(SingleXADatasourceConnectionTest, self).__init__(
            {
                "address": {
                    "subsystem": "datasources",
                    "xa-data-source": self.xaDatasourceName
                },
                "operation": "test-connection-in-pool"
            }
        )

    def evaluate(self, results):
        """
        Evaluates the test:
            READY if DMR query succeeded and the JDBC connection test returned 'True'
            NOT_READY if DMR query succeeded, but the JDBC connection test returned anything else
            FAILURE if the DMR query itself failed
        """

        # DMR query itself succeeded
        if results["outcome"] == "success":
            # And a XA datasource connection test returned 'True'. Return ready
            if str(results["result"][0]).lower() == "true":
                return (Status.READY, "Successfully created a JDBC connection for the '" + self.xaDatasourceName + "' XA datasource.")
            # And a XA datasource connection test returned anything else.
            # Return not ready (not failed, but e.g. might be still starting up etc.)
            else:
                return (Status.NOT_READY, "Failed to create a JDBC connection for the '" + self.xaDatasourceName + "' XA datasource.")
        # DMR query failed
        else:
            # The connection test returned e.g. a failure with description like:
            # "WFLYJCA0040: failed to invoke operation: WFLYJCA0047: Connection is not valid"
            # Return failure (test failed this time, but might succeed next time)
            return (Status.FAILURE, "Failed to create a JDBC connection for the '" + self.xaDatasourceName + "' XA datasource.")

class HealthCheckProbe(DmrProbe):
    """
    Basic EAP probe which uses the DMR interface to query server state. It
    defines tests for server status, boot errors and deployment status.
    """

    def __init__(self):
        super(HealthCheckProbe, self).__init__(
            [
                HealthCheckTest()
            ]
        )

class HealthCheckTest(Test):
    """
    Checks the state of the Health Check subsystem, if installed.
    We use a composite with a first step that does a simple read-resource
    and a second step that reads the health check status.
    A failure in the first step means the subsystem is not present and any
    failure in the second step should be ignored as meaningless.
    """

    def __init__(self):
        super(HealthCheckTest, self).__init__(
            {
                "operation": "composite",
                "address": [],
                "steps": [
                    {
                        "operation": "read-resource",
                        "address": {
                            "subsystem": "microprofile-health-smallrye"
                        },
                        "recursive" : False
                    },
                    {
                        "operation": "check",
                        "address": {
                            "subsystem": "microprofile-health-smallrye"
                        }
					}
				]
            }
        )

    def evaluate(self, results):
        """
        Evaluates the test:
            if the overall composite failed with JBAS014883 or WFLYCTL0030
                READY as the failure means no health check extension configured on the system
            elsif the 'read-resource' step failed:
                READY as failure means no health check subsystem configured on the system
            elsif the 'check' step succeeded:
                READY if the 'check' step result's status field is 'UP'
                HARD_FAILURE otherwise
            else:
                HARD_FAILURE as the query failed

        In no case do we return NOT_READY as MicroProfile Health Check is not a readiness check.
        """

        if results.get("failure-description") and re.compile("JBAS014883|WFLYCTL0030").search(str(results.get("failure-description"))):
            return (Status.READY, "Health Check not configured")

        if not results.get("result") or not results["result"].get("step-1"):
            return (Status.FAILURE, "DMR operation failed")

        if results["result"]["step-1"].get("outcome") != "success" and results["result"]["step-1"].get("failure-description"):
            return (Status.READY, "Health Check not configured")

        if not results["result"].get("step-2"):
            return (Status.HARD_FAILURE, "DMR operation failed " + str(results))

        if results["result"]["step-2"].get("outcome") != "success" or not results["result"]["step-2"].get("result"):
            return (Status.HARD_FAILURE, "DMR health check step failed " + str(results["result"]["step-2"]))

        status = results["result"]["step-2"]["result"].get("status")
        if status == "UP":
            return (Status.READY, "Status is UP")

        if status == "DOWN":
            return (Status.HARD_FAILURE, "Status is DOWN")

        return (Status.HARD_FAILURE, "DMR health check step failed " + str(results["result"]["step-2"]["result"]))

