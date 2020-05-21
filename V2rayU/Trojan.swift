//
//  Trojan.swift
//  V2rayU
//
//  Created by ust on 2020/5/19.
//  Copyright © 2020 yanue. All rights reserved.
//

import Alamofire
import SwiftyJSON

class Trojan {
    //配置当前的版本
    static let version = "1.15.1"
    // need replace ${version}
    var releaseUrl: String = "https://github.com/trojan-gfw/trojan/releases/download/v${version}/trojan-${version}-macos.zip"
    // lastet release verison info
    let versionUrl: String = "https://api.github.com/repos/trojan-gfw/trojan/releases/latest"
    
    func checkLocal(hasNewVersion: Bool) {
        // has new verion
        if hasNewVersion {
            // download new version
            self.download()
            return
        }

        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: trojanFile) {
            self.download();
        }
    }

    func check() {
        // 当前版本检测
        let oldVersion = UserDefaults.get(forKey: .trojanVersion) ?? Trojan.version

        Alamofire.request(versionUrl).responseJSON { response in
            var hasNewVersion = false

            defer {
                // check local file
                self.checkLocal(hasNewVersion: hasNewVersion)
            }

            //to get status code
            if let status = response.response?.statusCode {
                if status != 200 {
                    NSLog("error with response status: ", status)
                    return
                }
            }

            //to get JSON return value
            if let result = response.result.value {
                let JSON = result as! NSDictionary

                // get tag_name (verion)
                guard let tag_name = JSON["tag_name"] else {
                    NSLog("error: no tag_name")
                    return
                }

                // get prerelease and draft
                guard let prerelease = JSON["prerelease"], let draft = JSON["draft"] else {
                    // get
                    NSLog("error: get prerelease or draft")
                    return
                }

                // not pre release or draft
                if prerelease as! Bool == true || draft as! Bool == true {
                    NSLog("this release is a prerelease or draft")
                    return
                }

                let newVersion = tag_name as! String

                // get old versiion
                let oldVer = oldVersion.replacingOccurrences(of: "v", with: "").versionToInt()
                let curVer = newVersion.replacingOccurrences(of: "v", with: "").versionToInt()

                // compare with [Int]
                if oldVer.lexicographicallyPrecedes(curVer) {
                    // store this version
                    UserDefaults.set(forKey: .trojanVersion, value: newVersion)
                    // has new version
                    hasNewVersion = true
                    NSLog("has new version", newVersion)
                }

                return
            }
        }
    }

    func download() {
        let version = UserDefaults.get(forKey: .trojanVersion) ?? Trojan.version
        let url = releaseUrl.replacingOccurrences(of: "${version}", with: version)
        let fileName = "/trojan-macos.zip"
        NSLog("start download", version)

        // check unzip sh file
        // path: /Application/V2rayU.app/Contents/Resources/unzip.sh
        guard let shFile = Bundle.main.url(forResource: "unzip", withExtension: "sh") else {
            NSLog("unzip shell file no found")
            return
        }

        // download file: /Application/V2rayU.app/Contents/Resources/v2ray-macos.zip
        let fileUrl = URL.init(fileURLWithPath: shFile.path.replacingOccurrences(of: "/unzip.sh", with: fileName))
        //自定义文件名 https://blog.csdn.net/weixin_38735568/article/details/94717665
        let destination: DownloadRequest.DownloadFileDestination = { _ , _ in
            return (fileUrl, [.removePreviousFile, .createIntermediateDirectories])
        }

        let utilityQueue = DispatchQueue.global(qos: .utility)
        Alamofire.download(url, to: destination)
                .downloadProgress(queue: utilityQueue) { progress in
                    NSLog("已下载：\(progress.completedUnitCount / 1024)KB")
                }
                .responseData { response in
                    switch response.result {
                    case .success(_):
                        break
                    case .failure(_):
                        NSLog("error with response status:")
                        return
                    }

                    if let _ = response.result.value {
                        // make unzip.sh execable
                        // chmod 777 unzip.sh
                        let execable = "cd " + AppResourcesPath + " && /bin/chmod 777 ./unzip.sh"
                        _ = shell(launchPath: "/bin/bash", arguments: ["-c", execable])

                        // unzip trojan
                        // cmd: /bin/bash -c 'cd path && ./unzip.sh '
                        let sh = "cd " + AppResourcesPath + " && ./unzip.sh && /bin/chmod -R 777 ./trojan"
                        // exec shell
                        let res = shell(launchPath: "/bin/bash", arguments: ["-c", sh])
                        NSLog("res:", sh, res!)
                    }
                }
    }
}
