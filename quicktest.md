Manufacturer Library HAL
========================

Introduction
============

The *Manufacturer Library HAL* is responsible for retrieval of OEM serialization
data and managing the flash memory containing the device's software and along
with the [Front Panel Display](/display/ONEMPG/Front+Panel+Display) constitutes
the *Manufacturer Library*.

Note that there is a **different** component, unhelpfully named 'halmfr', which
is part of the *RDK Media Framework* and something completely different to
the *Manufacturer Library HAL*.

Relevant RDK Modules
====================

| **Manufacturer Library IARM Manager** | [rdk/components/generic/iarmmgrs/mfr](https://code.rdkcentral.com/r/plugins/gitiles/rdk/components/generic/iarmmgrs/+/master/mfr)                         |
|---------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Device Update IARM Manager**        | [rdk/components/generic/iarmmgrs/deviceUpdateMgr](https://code.rdkcentral.com/r/plugins/gitiles/rdk/components/generic/iarmmgrs/+/master/deviceUpdateMgr) |

A skeleton of the Manufacturer Library, specifying the APIs to be provided, can
be found
at [components/generic/mfrlibs](https://code.rdkcentral.com/r/plugins/gitiles/components/generic/mfrlibs/+/master) -
unfortunately this contains obsolete definitions and so
the components/generic/mfrlibs/mfrApi.h **should be
discarded** and [rdk/components/generic/iarmmgrs/mfr/include/mfrTypes.h](https://code.rdkcentral.com/r/plugins/gitiles/rdk/components/generic/iarmmgrs/+/master/mfr/include/mfrTypes.h) used
instead.

SoC Vendor Implementation Guidelines
====================================

The *Manufacturer Library HAL* is only to be implemented by the OEM, so there is
nothing for the SoC Vendor to do here.

OEM Implementation Guidelines
=============================

This section aims to clarify the documentation as provided on the [RDK-V OEM
Specific
Porting](https://wiki.rdkcentral.com/display/RDK/RDK-V+OEM+Specific+Porting#RDK-VOEMSpecificPorting-ManufacturerLibrary) page
at RDK Central.

The *Manufacturer Library HAL* is defined by the header files
at [rdk/components/generic/iarmmgrs/mfr/include](https://code.rdkcentral.com/r/plugins/gitiles/rdk/components/generic/iarmmgrs/+/master/mfr/include).
Note that mfrMgr.h is **not** intended to be implemented directly by the OEM
mfrlib!

The mainline RDK functionality described has been modified by LGI and is
described below, see section [LGI Extensions to
RDK](#ManufacturerLibraryHAL-LGIExtensionstoR)

Clarification of how to implement mfr\* functions
-------------------------------------------------

| **Function**         | **Used?** | **Implementation Notes**                                                                                                                                                                                                                                                                                                                     |
|----------------------|-----------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| mfr_init             |           | Implement as required by RDK. This may be invoked once per process from many processes, so be careful with any system-wide initialization (e.g. filesystem operations). This must be called by the user of the library before using any of the mfr\* functions, and the other API functions **may** assume that this has been invoked first. |
| mfrGetSerializedData |           | [See below](#ManufacturerLibraryHAL-Clarificationofh)                                                                                                                                                                                                                                                                                        |
| mfrWriteImage        |           | [See below](#ManufacturerLibraryHAL-Clarificationofh)                                                                                                                                                                                                                                                                                        |
| mfrDeletePDRI        |           | May return mfrERR_OPERATION_NOT_SUPPORTED                                                                                                                                                                                                                                                                                                    |
| mfrScrubAllBanks     |           | May return mfrERR_OPERATION_NOT_SUPPORTED                                                                                                                                                                                                                                                                                                    |

The feature macro ENABLE_MFR_WIFI is **not** defined and the APIs in
mfr_wifi_api.h do **not** need to be implemented. The APIs in mfr_temperature.h
are also **not** required.

Clarification of how to implement mfrGetSerializedData

Where indicated, the Integer value indicates a mandatory integer mapping of the
enum value which must be respected if One Middleware is to work properly. For
fields marked "unused", or where a feature is unsupported (e.g.
mfrSERIALIZED_TYPE_MOCAMAC on a device without MoCa), mfrGetSerializedData
should return mfrERR_INVALID_PARAM. For anything
else, mfrGetSerializedData should return mfrERR_OPERATION_NOT_SUPPORTED.

| **mfrGetSerializedData**            |                   |                                    |                      |                    |                                                                                                                                                                                                                                                |
|-------------------------------------|-------------------|------------------------------------|----------------------|--------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **enum**                            | **Integer value** | **Description**                    | **Type**             | **Example Value**  | **Notes**                                                                                                                                                                                                                                      |
| mfrSERIALIZED_TYPE_MANUFACTURER     | 0                 | Manufacturer Name                  | C-String             | "Yoyodyne"         |                                                                                                                                                                                                                                                |
| mfrSERIALIZED_TYPE_MANUFACTUREROUI  | 1                 | Organizationally Unique Identifier | C-String             | "3C36E4"           | OUI of OEM; not necessarily related to MAC address. See [CPE_ID convention](/pages/createpage.action?spaceKey=ONEMPG&title=CPE_ID+convention&linkCreation=true&fromPageId=202296542)                                                           |
| mfrSERIALIZED_TYPE_MODELNAME        | 2                 | Model Name                         | C-String             | "DCX960-PROD"      | OEM specific model name.                                                                                                                                                                                                                       |
| mfrSERIALIZED_TYPE_DESCRIPTION      | 3                 | **Unused**                         |                      |                    | Return mfrERR_INVALID_PARAM.                                                                                                                                                                                                                   |
| mfrSERIALIZED_TYPE_PRODUCTCLASS     | 4                 | Product Class                      | C-String             | "EOSSTB"           | Uppercase characters only, no whitespace. See [CPE_ID convention](/pages/createpage.action?spaceKey=ONEMPG&title=CPE_ID+convention&linkCreation=true&fromPageId=202296542)                                                                     |
| mfrSERIALIZED_TYPE_SERIALNUMBER     | 5                 | Serial Number                      | C-String             | "103618831907"     | 12-digit LGI ID. See [CPE_ID convention](/pages/createpage.action?spaceKey=ONEMPG&title=CPE_ID+convention&linkCreation=true&fromPageId=202296542)                                                                                              |
| mfrSERIALIZED_TYPE_HARDWAREVERSION  | 6                 | Hardware                           | C-String             | "YOYODYNE-EOS-V16" | Hardware manufacturer, name and revision. It is required that naming convention should be constructed in way that newer version should be always strcmp() \> 0. This allow simple define section of code for this and all following revisions. |
| mfrSERIALIZED_TYPE_SOFTWAREVERSION  | 7                 | One Middleware version             | C-String             | "00.01-047-aa"     | [See below](#ManufacturerLibraryHAL-SoftwareVersion)                                                                                                                                                                                           |
| mfrSERIALIZED_TYPE_PROVISIONINGCODE | 8                 | **Unused**                         |                      |                    | Return mfrERR_INVALID_PARAM.                                                                                                                                                                                                                   |
| mfrSERIALIZED_TYPE_FIRSTUSEDATE     | 9                 | **Unused**                         |                      |                    | Return mfrERR_INVALID_PARAM.                                                                                                                                                                                                                   |
| mfrSERIALIZED_TYPE_DEVICEMAC        | 10                | Wired ethernet interface MAC       | Hex-encoded C-String | "12421B4C1F98"     | 6 octets.                                                                                                                                                                                                                                      |
| mfrSERIALIZED_TYPE_MOCAMAC          | 11                | MoCa interface MAC                 | Hex-encoded C-String | "12421B4C1F98"     | 6 octets. **Must** return mfrERR_INVALID_PARAM if MoCa not supported.                                                                                                                                                                          |
| mfrSERIALIZED_TYPE_HDMIHDCP         | 12                | HDCP 1.4 key                       | binary blob          | \<binary data\>    | Data is opaque to OneMW. **Must** be encrypted and decryptable by SoC                                                                                                                                                                          |
| mfrSERIALIZED_TYPE_PDRIVERSION      | 13                | **Unused**                         |                      |                    | Return mfrERR_INVALID_PARAM.                                                                                                                                                                                                                   |
| mfrSERIALIZED_TYPE_BLUETOOTHMAC     |                   | Bluetooth interface MAC            | Hex-encoded C-String | "12421B4C1F98"     | 6 octets. **Must** return mfrERR_INVALID_PARAM if Bluetooth not supported.                                                                                                                                                                     |
| mfrSERIALIZED_TYPE_WIFIMAC          |                   | WLAN interface MAC                 | Hex-encoded C-String | "12421B4C1F98"     | 6 octets. **Must** return mfrERR_INVALID_PARAM if WiFi not supported.                                                                                                                                                                          |

-   DVR and nonDVR should have different model names

-   Model name should also include model variation -DEV -PROD

### Software Version

The software version field - the One Middleware version - has
format "hhhhhhhh-mmm-ccc-xx.xx-yyy-zz...". The version is the "xx.xx-yyy-zz"
part. For example, the version file may contain the string
"DCX960__-mon-dbg-00.01-047-aa-AL-20180523125607-un000". The software version
field will then be equal to "00.01-047-aa".

The version **may be** extracted from the One Middleware version
file /etc/version or from elsewhere in the device depending on how the OEM
firmware works.

### Notes on Serialized Data Types

-   All *C-Strings* are 0-terminated. The buffer length of the returned data
    must take this into account.

-   *Hex-encoded C-Strings* are encoded highest significant octet
    first, **without** delimiting colons or radix information (i.e. without any
    '0x'). Uppercase is **preferred** (i.e. "02421B4C1F98" rather than
    "02421b4c1f98").

-   Binary blobs **must not** be terminated with an additional NUL and the
    buffer length of the returned data **must** be equal to the length of the
    binary blob.

Clarification of how to implement mfrWriteImage
-----------------------------------------------

The Manufacturer Library HAL function mfrWriteImage is used by the One
Middleware *Device Update Module* to initiate a firmware update. The *Device
Update Module* calls mfrWriteImage as follows:

mfrWriteImage(directory, filename, mfrIMAGE_TYPE_CDL, notify)

The inline documentation of the function in RDK is misleading and incorrect, so
to clarify:

-   The first argument is the *directory* of the firmware update file

-   The second argument is the *filename* of the firmware update file within the
    directory specified in the first argument

-   The third argument is always set to mfrIMAGE_TYPE_CDL and should be ignored.

-   The fourth argument is set by One Middleware to a callback which must be
    invoked to indicate the status of the firmware update process as described
    in the inline documentation in mfrTypes.h

The notify callback **must** be invoked to indicate completion or error (with
argument mfrUPGRADE_PROGRESS_ABORTED or mfrUPGRADE_PROGRESS_COMPLETED) once
only. The update **may** be executed synchronously from the main thread **or**
asynchronously from a helper thread (but there is no requirement to do so).

Process / thread context considerations
---------------------------------------

Calls to the *Manufacturer Library HAL* are made from the *mfr Manager* and are
strictly serial within this single process - with a couple of exceptions.

-   The One Middleware *Device Update Module*, controlled by the [Device Update
    Manager](https://wiki.rdkcentral.com/display/RDK/Device+Update+Manager),
    calls mfrWriteImage directly from the *Device Update Manager* daemon. Calls
    to mfrWriteImage are strictly serial within this process, but not relative
    to other functions of the *Manufacturer Library API*.

-   The LGI extension function, mfrGetSerializedDataPriv, is not made available
    via IARM, but is called by various processes. These calls are strictly
    serial within a process, but there may be several processes using this
    function.

Since the *Manufacturer Library HAL* is mostly only returning read-only data, so
the above should not cause many (or any) problems or implementation
difficulties.

LGI Extensions to RDK
=====================

Modified definitions can be found in the build output
(i.e. build-\<target\>/tmp/)
at: sysroots/\<target\>/usr/include/rdk/iarmmgrs/mfr/mfrTypes.h. Where
indicated, the *Integer value* indicates a **mandatory** integer mapping of the
enum value which must be respected if OneMiddleware is to work properly.

Extra fields in mfrGetSerializedData
------------------------------------

The following additional fields of mfrGetSerializedData are required to be
implemented to support OneMiddleware

| **mfrGetSerializedData**         |                   |                 |                      |                   |                                                                     |
|----------------------------------|-------------------|-----------------|----------------------|-------------------|---------------------------------------------------------------------|
| **enum**                         | **Integer value** | **Description** | **Type**             | **Example Value** | **Notes**                                                           |
| Reserved                         | 14                | **Unused**      |                      |                   | Return mfrERR_INVALID_PARAM.                                        |
| mfrSERIALIZED_TYPE_CMCHIPVERSION | 15                | LGI Soc ID      | Hex-encoded C-String | "AA551234CDB1"    | 8 octets. Return mfrERR_INVALID_PARAM if device does not have this. |

Additional functions in Manufacturer Library HAL
------------------------------------------------

| **Function**             | **Implementation Notes**                              |
|--------------------------|-------------------------------------------------------|
| mfr_shutdown             | Counterpart to mfr_init, release resources etc.       |
| mfrGetSerializedDataPriv | [See below](#ManufacturerLibraryHAL-mfrGetSerialized) |
| mfrReboot                | **Must** invoke command: /bin/systemctl reboot        |
| mfrHalt                  | **Must** invoke command: /bin/systemctl halt          |

mfrGetSerializedDataPriv
------------------------

A new function, mfrGetSerializedDataPriv, has been added to the *Manufacturer
Library HAL*.

Where indicated, the Integer value indicates a mandatory integer mapping of the
enum value which must be respected if OneMiddleware is to work properly.
Unfortunately, some fields are duplicated
from [mfrGetSerializedData above](#ManufacturerLibraryHAL-Clarificationofh). For
fields marked "deprecated", or where a feature is unsupported
(e.g. mfrSERIALIZED_PRIV_HDD on a device without a
HDD), mfrGetSerializedData should return mfrERR_INVALID_PARAM. For anything
else, mfrGetSerializedDataPriv should return mfrERR_OPERATION_NOT_SUPPORTED.

| **mfrGetSerializedDataPriv**          |                                            |             |                   |                                                                                                                                                                                                                                |
|---------------------------------------|--------------------------------------------|-------------|-------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **enum**                              | **Description**                            | **Type**    | **Example Value** | **Notes**                                                                                                                                                                                                                      |
| mfrSERIALIZED_PRIV_DEVICEMAC          | **Deprecated**                             |             |                   | May return mfrERR_INVALID_PARAM or same as mfrGetSerializedData(mfrSERIALIZED_TYPE_DEVICEMAC)                                                                                                                                  |
| mfrSERIALIZED_PRIV_MOCAMAC            |                                            |             |                   | Identical to mfrGetSerializedData(mfrSERIALIZED_TYPE_MOCAMAC)                                                                                                                                                                  |
| mfrSERIALIZED_PRIV_WIFIMAC            |                                            |             |                   | Identical to mfrGetSerializedData(mfrSERIALIZED_TYPE_WIFIMAC)                                                                                                                                                                  |
| mfrSERIALIZED_PRIV_MODELNAME          | **Deprecated**                             |             |                   | May return mfrERR_INVALID_PARAM or same as mfrGetSerializedData(mfrSERIALIZED_TYPE_MODELNAME)                                                                                                                                  |
| mfrSERIALIZED_PRIV_FAN                | **Deprecated**                             |             |                   | Return mfrERR_INVALID_PARAM                                                                                                                                                                                                    |
| mfrSERIALIZED_PRIV_HDD                | Hard disk size                             | C-String    | "1TB"             | **Must** return a non-empty string if hard disk drive is installed in device. Return mfrERR_INVALID_PARAM if device does not have a hard disk. SD-Cards and other flash devices are **not** considered to be hard disk drives. |
| mfrSERIALIZED_PRIV_HDMIHDCP           |                                            |             |                   | Identical to mfrGetSerializedData(mfrSERIALIZED_TYPE_HDMIHDCP)                                                                                                                                                                 |
| mfrSERIALIZED_PRIV_HDMIHDCP22         | HDCP 2.2 key                               | binary blob | \<binary data\>   | Data is opaque to OneMW. **Must** be encrypted and decryptable by SoC. Return mfrERR_INVALID_PARAM if device does not support this.                                                                                            |
| mfrSERIALIZED_PRIV_IRDE               | Certificates and keys packed in Irdeto DKP | binary blob | \<binary data\>   | [See below](#ManufacturerLibraryHAL-IRDEFormat)                                                                                                                                                                                |
| mfrSERIALIZED_PRIV_PKEY               | **Deprecated**                             |             |                   | Return mfrERR_INVALID_PARAM.                                                                                                                                                                                                   |
| mfrSERIALIZED_PRIV_CASN               | CA Serial Number                           | C-String    | "001234567899"    | 12 digits in total, including leading zeros and 2 control digits. Return mfrERR_INVALID_PARAM if not relevant to device.                                                                                                       |
| mfrSERIALIZED_PRIV_CHIPREV            | Chip revision                              | C-String    | "A0"              | Exact format will be platform specific.                                                                                                                                                                                        |
| mfrSERIALIZED_PRIV_BLVERSION          | Version of Bootloader                      | C-String    | "0.0.0"           | Exact format will be platform specific.                                                                                                                                                                                        |
| mfrSERIALIZED_PRIV_RLVERSION          | Version of Rescue Loader                   | C-String    | "0.0.0"           | Exact format will be platform specific.                                                                                                                                                                                        |
| mfrSERIALIZED_PRIV_OEMSERIALNO        | STB serial number as given by manufacturer | C-String    | "YO1234"          | Chosen by OEM.                                                                                                                                                                                                                 |
| mfrSERIALIZED_PRIV_BSECKVERSION       | Version of BSECK                           | C-String    | "0.0.0"           | Only relevant to Broadcom platforms. Return mfrERR_INVALID_PARAM if not relevant or unavailable.                                                                                                                               |
| mfrSERIALIZED_PRIV_OEMSOFTWAREVERSION | OEM Software version                       | C-String    | "0.0.0"           | If the device stores a main software version different (but possibly related to) to the One Middleware software version, return this as a string. Otherwise return mfrERR_INVALID_PARAM if not relevant.                       |

IRDE Format
-----------

In general, the IRDE blob will be stored as an opaque object to be passed
straight through to *One Middleware* from the *Manufacturer Library*, so there
is no reason to describe the format here. If for some reason the *Manufacturer
Library HAL* needs to understand the IRDE format (e.g. legacy platform with
separately packaged key material), this should be discussed with LGI.

One Middleware Manufacturer Library Stub
========================================

A simple skeleton implementation of the *Manufacturer Library HAL* has been
created
at: [meta-lgi-om-common/meta-lgi-om/meta-pal/rdkmfrlib-mock/rdkmfrlib-mock](https://github.com/LibertyGlobal/meta-lgi-om-common/tree/master/meta-lgi-om/meta-pal/rdkmfrlib-mock).
This can be used as a starting point to implement the *Manufacturer Library*.
