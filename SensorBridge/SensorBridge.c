#include "SensorBridge.h"
#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <string.h>
#include <math.h>
#include <dlfcn.h>

typedef struct { unsigned char major, minor, build, reserved; unsigned short release; } SMCVersion;
typedef struct { unsigned short version, length; unsigned int cpuPLimit, gpuPLimit, memPLimit; } SMCPLimitData;
typedef struct { unsigned int dataSize, dataType; unsigned char dataAttributes; } SMCKeyInfoData;
typedef struct {
    unsigned int key;
    SMCVersion vers;
    SMCPLimitData pLimitData;
    SMCKeyInfoData keyInfo;
    unsigned char result, status;
    unsigned char data8;
    unsigned int data32;
    unsigned char bytes[32];
} SMCKeyData;

static unsigned int fourcc(const char *key) {
    return ((unsigned int)(unsigned char)key[0] << 24) | ((unsigned int)(unsigned char)key[1] << 16) |
           ((unsigned int)(unsigned char)key[2] << 8) | (unsigned int)(unsigned char)key[3];
}

static double readKey(io_connect_t connection, const char *key) {
    SMCKeyData input = {0}, output = {0};
    size_t outputSize = sizeof(output);
    input.key = fourcc(key);
    input.data8 = 9; /* get key info */
    kern_return_t result = IOConnectCallStructMethod(connection, 2, &input, sizeof(input), &output, &outputSize);
    if (result != KERN_SUCCESS || output.keyInfo.dataSize == 0 || output.keyInfo.dataSize > 32) return NAN;

    input.keyInfo = output.keyInfo;
    input.data8 = 5; /* read bytes */
    memset(&output, 0, sizeof(output));
    outputSize = sizeof(output);
    result = IOConnectCallStructMethod(connection, 2, &input, sizeof(input), &output, &outputSize);
    if (result != KERN_SUCCESS) return NAN;

    unsigned int type = output.keyInfo.dataType ? output.keyInfo.dataType : input.keyInfo.dataType;
    if (type == fourcc("sp78") && input.keyInfo.dataSize >= 2)
        return (double)((short)((output.bytes[0] << 8) | output.bytes[1])) / 256.0;
    if ((type == fourcc("flt ") || type == fourcc("flt")) && input.keyInfo.dataSize >= 4) {
        uint32_t bits = ((uint32_t)output.bytes[0] << 24) | ((uint32_t)output.bytes[1] << 16) |
                        ((uint32_t)output.bytes[2] << 8) | output.bytes[3];
        float value;
        memcpy(&value, &bits, sizeof(value));
        return value;
    }
    return NAN;
}

/* Apple silicon exposes its die thermometers as vendor-defined HID events. These
   APIs are dynamically resolved so an older macOS version can still launch and
   use the AppleSMC path below. */
static double readAppleSiliconHIDTemperature(void) {
    typedef void *(*CreateClientFn)(CFAllocatorRef);
    typedef CFArrayRef (*CopyServicesFn)(void *);
    typedef Boolean (*ConformsFn)(void *, uint32_t, uint32_t);
    typedef CFTypeRef (*CopyPropertyFn)(void *, CFStringRef);
    typedef void *(*CopyEventFn)(void *, int64_t, int32_t, int64_t);
    typedef double (*GetFloatValueFn)(void *, int32_t);

    void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY | RTLD_LOCAL);
    if (!handle) return NAN;
    CreateClientFn createClient = (CreateClientFn)dlsym(handle, "IOHIDEventSystemClientCreate");
    CopyServicesFn copyServices = (CopyServicesFn)dlsym(handle, "IOHIDEventSystemClientCopyServices");
    ConformsFn conforms = (ConformsFn)dlsym(handle, "IOHIDServiceClientConformsTo");
    CopyPropertyFn copyProperty = (CopyPropertyFn)dlsym(handle, "IOHIDServiceClientCopyProperty");
    CopyEventFn copyEvent = (CopyEventFn)dlsym(handle, "IOHIDServiceClientCopyEvent");
    GetFloatValueFn getFloatValue = (GetFloatValueFn)dlsym(handle, "IOHIDEventGetFloatValue");
    if (!createClient || !copyServices || !conforms || !copyProperty || !copyEvent || !getFloatValue) {
        dlclose(handle);
        return NAN;
    }

    void *client = createClient(kCFAllocatorDefault);
    if (!client) { dlclose(handle); return NAN; }
    CFArrayRef services = copyServices(client);
    double total = 0;
    int valid = 0;
    if (services) {
        CFIndex count = CFArrayGetCount(services);
        for (CFIndex i = 0; i < count; i++) {
            void *service = (void *)CFArrayGetValueAtIndex(services, i);
            if (!conforms(service, 0xff00, 5)) continue;
            CFTypeRef product = copyProperty(service, CFSTR("Product"));
            char name[128] = {0};
            Boolean isDie = product && CFGetTypeID(product) == CFStringGetTypeID() &&
                CFStringGetCString((CFStringRef)product, name, sizeof(name), kCFStringEncodingUTF8) &&
                strstr(name, "tdie") != NULL;
            if (product) CFRelease(product);
            if (!isDie) continue;
            void *event = copyEvent(service, 15, 0, 0);
            if (!event) continue;
            double value = getFloatValue(event, 15 << 16);
            CFRelease(event);
            if (isfinite(value) && value > 10 && value < 125) { total += value; valid++; }
        }
        CFRelease(services);
    }
    CFRelease(client);
    dlclose(handle);
    return valid ? total / valid : NAN;
}

double SensorBridgeCPUAndAverageTemperature(void) {
    double hidTemperature = readAppleSiliconHIDTemperature();
    if (isfinite(hidTemperature)) return hidTemperature;

    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return NAN;
    io_connect_t connection = IO_OBJECT_NULL;
    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, &connection);
    IOObjectRelease(service);
    if (result != KERN_SUCCESS) return NAN;

    /* Intel CPU proximity/core keys followed by common Apple-silicon SoC keys. */
    static const char *keys[] = { "TC0P", "TC0D", "TC0E", "TC0F", "TC1C", "TC2C", "Tp09", "Tp0T", "Tp01", "Tp05" };
    double total = 0;
    int valid = 0;
    for (unsigned long i = 0; i < sizeof(keys) / sizeof(keys[0]); i++) {
        double value = readKey(connection, keys[i]);
        if (isfinite(value) && value > 10 && value < 125) { total += value; valid++; }
    }
    IOServiceClose(connection);
    return valid ? total / valid : NAN;
}
