#!/usr/bin/env python3
"""Run the RDK-B Incus integration tests used by the CI pipeline."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request
from pathlib import Path
from typing import Any

IN_USE_MARKER = Path("/tmp/incus_in_use")
IMAGE_FILENAME = "rdk-generic-broadband-image-armefi64-rdk-broadband.wic.qcow2"
IMAGE_URL = (
    "https://traverse-rdkb-ci-builds.s3.bhs.io.cloud.ovh.net/ci-builds/"
    "{pipeline_id}/generic/" + IMAGE_FILENAME
)


def run(
    args: list[str],
    *,
    check: bool = True,
    quiet: bool = False,
) -> subprocess.CompletedProcess[str]:
    """Run a command without a shell; show output unless the caller needs it."""
    result = subprocess.run(
        args,
        check=False,
        text=True,
        stdout=subprocess.PIPE if quiet else None,
        stderr=subprocess.PIPE if quiet else None,
    )
    if check and result.returncode:
        if quiet:
            if result.stdout:
                print(result.stdout, end="", file=sys.stderr)
            if result.stderr:
                print(result.stderr, end="", file=sys.stderr)
        raise subprocess.CalledProcessError(result.returncode, args)
    return result


def output(args: list[str], *, allow_failure: bool = False) -> str:
    result = run(args, check=not allow_failure, quiet=True)
    return (result.stdout or "").strip()


def incus_instance_info(name: str) -> dict[str, Any]:
    result = output(["incus", "list", "-f", "json", name])
    instances = json.loads(result)
    if not instances:
        raise RuntimeError(f"Incus did not return instance information for {name}")
    return instances[0]


def global_addresses(instance: dict[str, Any], interface: str) -> list[dict[str, Any]]:
    network = instance.get("state", {}).get("network", {})
    iface = network.get(interface, {})
    return [
        address
        for address in (iface.get("addresses") or [])
        if address and address.get("scope") == "global"
    ]


def schedule_cleanup(project_name: str, network_name: str) -> None:
    """Schedule removal of the temporary project and network after two hours."""
    print("Scheduling deletion of test environment in two hours")
    script = f'''#!/bin/sh
while [ -f {IN_USE_MARKER} ]; do sleep 60; done
incus project switch default
(echo yes | incus project rm -f "{project_name}") > /dev/null
(echo yes | incus network rm "{network_name}") > /dev/null
'''
    fd, filename = tempfile.mkstemp(prefix="incus-cleanup-")
    cleanup_file = Path(filename)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as file:
            file.write(script)
        env = {"HOME": os.environ.get("HOME", str(Path.home()))}
        run(["at", "-f", str(cleanup_file), "now + 2 hours"], check=True)
    finally:
        cleanup_file.unlink(missing_ok=True)


def cleanup(project_name: str, network_name: str, router_name: str, client_name: str) -> None:
    # Keep attempting the remaining cleanup steps if one of them fails.
    for name in (client_name, router_name):
        try:
            run(["incus", "stop", "-f", name], check=False)
        except OSError as error:
            print(f"Warning: could not stop {name}: {error}", file=sys.stderr)
    try:
        run(["incus", "project", "switch", "default"], check=False)
    except OSError as error:
        print(f"Warning: could not switch to the default Incus project: {error}", file=sys.stderr)

    IN_USE_MARKER.unlink(missing_ok=True)
    try:
        schedule_cleanup(project_name, network_name)
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"Warning: could not schedule environment deletion: {error}", file=sys.stderr)


def require_pipeline_id() -> str:
    pipeline_id = os.environ.get("CI_PIPELINE_ID")
    if not pipeline_id:
        raise RuntimeError("CI_PIPELINE_ID must be set")
    return pipeline_id


def first_global_address(instance: dict[str, Any], interface: str, family: str) -> str | None:
    for address in global_addresses(instance, interface):
        if address.get("family") == family:
            return str(address.get("address", ""))
    return None


def run_tests() -> None:
    pipeline_id = require_pipeline_id()
    project_name = f"rdkb-test-{pipeline_id}"
    image_name = f"rdkb-{pipeline_id}"
    router_name = f"rdkb-ci-test-{pipeline_id}"
    client_name = f"testclient-{pipeline_id}"
    network_name = f"r2c-{pipeline_id}"
    environment_created = False

    IN_USE_MARKER.touch()
    try:
        Path("metadata.yaml").write_text(
            "architecture: arm64\n"
            f"creation_date: {int(time.time())}\n"
            "properties:\n"
            "  description: RDK-B image\n"
            "  os: RDK-B\n"
            "  release: 20260520061518\n",
            encoding="utf-8",
        )

        run(["incus", "project", "create", project_name])
        environment_created = True
        run(["incus", "project", "switch", project_name])
        run(
            [
                "incus", "network", "create", network_name,
                "dns.mode=none", "ipv4.address=none", "ipv6.address=none",
                "--type=bridge",
            ]
        )

        with tarfile.open("metadata.tar.gz", "w:gz") as archive:
            archive.add("metadata.yaml", arcname="metadata.yaml")

        image_path = Path(IMAGE_FILENAME)
        image_url = IMAGE_URL.format(pipeline_id=pipeline_id)
        print(f"Downloading image from {image_url}")
        urllib.request.urlretrieve(image_url, image_path)
        run(["incus", "image", "import", "metadata.tar.gz", str(image_path), "--alias", image_name])

        run(
            [
                "incus", "create", image_name, router_name, "--vm",
                "--storage", "default", "-c", "security.secureboot=false",
                "-c", "limits.cpu=2", "-c", "limits.memory=2GiB",
                "-n", network_name,
            ]
        )
        run(["incus", "network", "attach", "bng2cpe", router_name, "eth1"])
        run(["incus", "start", router_name])
        run(
            [
                "incus", "create", "--storage", "default", "images:alpine/3.23",
                client_name, "-n", network_name,
            ]
        )
        run(["incus", "start", client_name])

        print("Waiting for stack to boot")
        time.sleep(30)

        router = incus_instance_info(router_name)
        if router.get("state", {}).get("status") != "Running":
            raise RuntimeError("ERROR: RDK-B VM is not running")
        print("VM is running")

        vm_os_info: dict[str, Any] = {}
        vm_os_name = ""
        for attempt in range(5):
            router = incus_instance_info(router_name)
            vm_os_info = router.get("state", {}).get("os_info") or {}
            vm_os_name = str(vm_os_info.get("os", ""))
            if "RDK" in vm_os_name:
                break
            if attempt < 4:
                time.sleep(20)
        else:
            raise RuntimeError(
                "ERROR: Virtual machine is not identifying as RDK-B "
                f"(missing incus agent issue?). VM reported name is: {vm_os_name}"
            )

        print("Reported OS information:")
        print(json.dumps(vm_os_info, indent=2))
        print("version.txt from VM:")
        print("------------------------------------------------------")
        run(["incus", "exec", router_name, "--", "cat", "/version.txt"])
        print("------------------------------------------------------")

        brlan0_status = "unknown"
        for attempt in range(5):
            router = incus_instance_info(router_name)
            brlan0_status = (
                router.get("state", {}).get("network", {}).get("brlan0", {}).get("state", "unknown")
            )
            if brlan0_status == "up":
                break
            print("Waiting for brlan0 to startup")
            if attempt < 4:
                time.sleep(20)
        if brlan0_status != "up":
            raise RuntimeError("ERROR: brlan0 interface is not present")

        router_ipv4 = router_ipv6 = None
        for attempt in range(15):
            router = incus_instance_info(router_name)
            router_ipv4 = first_global_address(router, "brlan0", "inet") or router_ipv4
            router_ipv6 = first_global_address(router, "brlan0", "inet6") or router_ipv6
            if router_ipv4 and router_ipv6:
                break
            if attempt < 14:
                time.sleep(30)
        if not router_ipv4:
            raise RuntimeError("ERROR: Router did not assign an IPv4 address to brlan0")
        if not router_ipv6:
            raise RuntimeError("ERROR: Router did not assign an IPv6 address to brlan0")
        print(f"Router IPv4 LAN address: {router_ipv4}")
        print(f"Router IPv6 LAN address: {router_ipv6}")

        client_ipv4 = client_ipv6 = None
        for attempt in range(10):
            client = incus_instance_info(client_name)
            client_ipv4 = first_global_address(client, "eth0", "inet") or client_ipv4
            client_ipv6 = first_global_address(client, "eth0", "inet6") or client_ipv6
            if client_ipv4 and client_ipv6:
                break
            if attempt < 9:
                time.sleep(30)
        if not client_ipv4:
            raise RuntimeError("ERROR: Test client failed to gain IPv4 address")
        if not client_ipv6:
            raise RuntimeError("ERROR: Test client failed to acquire IPv6 address")
        print(f"Client IPv4 LAN address: {client_ipv4}")
        print(f"Client IPv6 LAN address: {client_ipv6}")

        print("Running local dmcli / TR-181 test (DHCP)")
        dhcp_enabled = "false"
        for attempt in range(6):
            dhcp_enabled = output(
                [
                    "incus", "exec", router_name, "--", "dmcli", "eRT", "retv",
                    "Device.DHCPv4.Server.Pool.1.Enable",
                ],
                allow_failure=True,
            ) or "false"
            if dhcp_enabled == "true":
                break
            if attempt < 5:
                time.sleep(10)
        if dhcp_enabled != "true":
            raise RuntimeError("ERROR: Device.DHCPv4.Server. is not responding")

        run(
            [
                "incus", "exec", router_name, "--", "dmcli", "eRT", "getv",
                "Device.DHCPv4.Server.Pool.1.Client.1.",
            ],
            check=False,
        )
        client_ipv4_tr181 = output(
            [
                "incus", "exec", router_name, "--", "dmcli", "eRT", "retv",
                "Device.DHCPv4.Server.Pool.1.Client.1.IPv4Address.1.IPAddress",
            ],
            allow_failure=True,
        )
        if client_ipv4 != client_ipv4_tr181:
            raise RuntimeError(
                "ERROR: IPv4 Address for test client does not match value in TR181\n"
                f"TR181 says: {client_ipv4_tr181}"
            )

        print("Running local dmcli / TR-181 test (DeviceInfo WAN Address)")
        wan_ip_address = output(
            [
                "incus", "exec", router_name, "--", "dmcli", "eRT", "retv",
                "Device.DeviceInfo.X_COMCAST-COM_WAN_IP",
            ],
            allow_failure=True,
        )
        if not wan_ip_address:
            raise RuntimeError("ERROR: Unable to obtain WAN IP address via TR181")
        print(f"WAN IP address (reported by TR181): {wan_ip_address}")
        run(["incus", "list"])
    finally:
        # The marker prevents a previously scheduled cleanup from deleting a live
        # environment while this job is using Incus.
        if environment_created:
            cleanup(project_name, network_name, router_name, client_name)
        else:
            IN_USE_MARKER.unlink(missing_ok=True)


def main() -> int:
    try:
        run_tests()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
