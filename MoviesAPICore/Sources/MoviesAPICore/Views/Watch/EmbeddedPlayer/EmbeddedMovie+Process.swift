//
//  EmbeddedMovie+Process.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import WebKit
import ProccesInfo

extension WebView.Coordinator {

    internal func loadPID(for webView: WKWebView) {
#if os(macOS)
        self.pid = WebKitProcessLocator.webProcessIdentifier(for: webView)
#endif
    }

    internal func loadStartTimeForPID() {
#if os(macOS)
        guard let pid else { return }
        var start_time: timeval = .init();
        get_process_start_time(pid, &start_time);

        let seconds = TimeInterval(start_time.tv_sec)
        let microseconds = TimeInterval(start_time.tv_usec) / 1_000_000
        let startDate = Date(timeIntervalSince1970: seconds + microseconds)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        print("Start Time: \(formatter.string(from: startDate))")
#endif
    }

    internal func beginMonitoringPID() {
#if os(macOS)
        perfMonitor?.cancel()

        var lastCPUTime: UInt64 = 0
        var lastPidChecked: pid_t? = nil

        perfMonitor = Task.detached(priority: .background) { [weak self] in

            func getMemory(for pid: pid_t) -> Double {
                let mem = getMemoryForProcess(pid)
                let gb = Double(mem) / 1_000_000_000
                return gb
            }

            func getCPUUsage(for pid: pid_t) -> (Int32, Double) {

                if lastPidChecked != pid {
                    lastPidChecked = pid
                    lastCPUTime = 0
                }

                var processThreadInfo: ProcessThreadInfo = .init()
                let result = getCPUInfo(pid, &processThreadInfo)
                if result == -1 {
                    return (0, 0)
                }

                let cpuTime = processThreadInfo.cpuTime

                guard cpuTime >= lastCPUTime else {
                    lastCPUTime = cpuTime
                    return (processThreadInfo.count, 0.0)
                }

                if lastCPUTime != 0 {
                    let delta = cpuTime - lastCPUTime
                    let cpuSeconds = Double(delta) / 1_000_000_000
                    let cpuPercent = (cpuSeconds / 5.0) * 100.0
                    lastCPUTime = cpuTime
                    return (processThreadInfo.count, cpuPercent)
                }

                lastCPUTime = cpuTime
                return (processThreadInfo.count, 0);
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self else { return }
                guard let pid = await pid else { continue }

                let mem = getMemory(for: pid)
                //                print("\(pid) Memory: \(mem)GB")
                await memoryInfo(mem)

                let (threadCount, cpu) = getCPUUsage(for: pid)
                //                print("CPU: \(String(format: "%.2f", cpu))%")
                //                print("Thread Count: \(threadCount)")

                await threadInfo(threadCount)
                await cpuInfo(cpu)
            }
        }
#endif
    }

#if DEBUG
    internal func findProcessMethods(_ object: AnyObject) {
        var cls: AnyClass? = object_getClass(object)

        while let current = cls {
            print("\n=== \(NSStringFromClass(current)) ===")

            var count: UInt32 = 0

            if let methods = class_copyMethodList(current, &count) {
                defer { free(methods) }

                for i in 0..<Int(count) {
                    let selector = method_getName(methods[i])
                    let name = NSStringFromSelector(selector)

                    if name.localizedCaseInsensitiveContains("process") ||
                        name.localizedCaseInsensitiveContains("pid") {
                        print(name)
                    }
                }
            }

            cls = class_getSuperclass(current)
        }
    }
#endif
}
