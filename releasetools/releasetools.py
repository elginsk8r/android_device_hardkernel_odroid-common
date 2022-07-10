#!/bin/env python3
#
# Copyright (C) 2020-2021 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

import common
import re

def FullOTA_InstallEnd(info):
  OTA_InstallEnd(info)
  return

def IncrementalOTA_InstallEnd(info):
  OTA_InstallEnd(info)
  return

def AddImage(info, folder, basename, dest):
  name = basename
  data = info.input_zip.read(folder + basename)
  common.ZipWriteStr(info.output_zip, name, data)
  info.script.AppendExtra('package_extract_file("%s", "%s");' % (name, dest))

def AddDtbImage(info, folder, basename):
  name = basename
  data = info.input_zip.read(folder + basename)
  common.ZipWriteStr(info.output_zip, name, data)
  info.script.AppendExtra('package_extract_file("%s", "/tmp/dtb.img");' % name);
  info.script.AppendExtra('run_program("/system/bin/dd", "if=/tmp/dtb.img", "of=/dev/block/dtbs", "bs=1k", "count=256");');

def PrintInfo(info, dest):
  info.script.Print("Patching {} image unconditionally...".format(dest.split('/')[-1]))

def OTA_InstallEnd(info):
  if 'RADIO/dtb.img' in info.input_zip.namelist():
    PrintInfo(info, "/dev/block/dtbs")
    AddDtbImage(info, "RADIO/", "dtb.img")
  if 'RADIO/bootloader.img' in info.input_zip.namelist():
    PrintInfo(info, "/dev/block/bootloader")
    AddImage(info, "RADIO/", "bootloader.img", "/dev/block/bootloader")
  return
