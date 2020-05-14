import ShellOut
import Vapor


struct AppEnvironment {
    var date: () -> Date
    var fetchMasterPackageList: (_ client: Client) throws -> EventLoopFuture<[URL]>
    var fetchMetadata: (_ client: Client, _ package: Package) throws -> EventLoopFuture<Github.Metadata>
    var fileManager: FileManager
    var githubToken: () -> String?
    var reportError: (_ client: Client, _ level: AppError.Level, _ error: Error) -> EventLoopFuture<Void>
    var rollbarToken: () -> String?
    var shell: Shell
}

extension AppEnvironment {
    static let live: Self = .init(
        date: Date.init,
        fetchMasterPackageList: liveFetchMasterPackageList,
        fetchMetadata: Github.fetchMetadata(client:package:),
        fileManager: .live,
        githubToken: { Environment.get("GITHUB_TOKEN") },
        reportError: AppError.report,
        rollbarToken: { Environment.get("ROLLBAR_TOKEN") },
        shell: .live
    )
}


struct FileManager {
    var checkoutsDirectory: () -> String
    var createDirectory: (String, Bool, [FileAttributeKey : Any]?) throws -> Void
    var fileExists: (String) -> Bool
    var workingDirectory: () -> String
    // also provide pass-through methods to preserve argument labels
    func createDirectory(atPath path: String,
                         withIntermediateDirectories createIntermediates: Bool,
                         attributes: [FileAttributeKey : Any]?) throws {
        try createDirectory(path, createIntermediates, attributes)
    }
    func fileExists(atPath path: String) -> Bool { fileExists(path) }

    static let live: Self = .init(
        checkoutsDirectory: { Environment.get("CHECKOUTS_DIR") ?? DirectoryConfiguration.detect().workingDirectory + "SPI-checkouts" },
        createDirectory: Foundation.FileManager.default.createDirectory(atPath:withIntermediateDirectories:attributes:),
        fileExists: Foundation.FileManager.default.fileExists(atPath:),
        workingDirectory: { DirectoryConfiguration.detect().workingDirectory }
    )
}


extension FileManager {
    func cacheDirectoryPath(for package: Package) -> String? {
        guard let dirname = package.cacheDirectoryName else { return nil }
        return checkoutsDirectory() + "/" + dirname
    }
}


struct Shell {
    var run: (ShellOutCommand, String) throws -> String
    // also provide pass-through methods to preserve argument labels
    @discardableResult
    func run(command: ShellOutCommand, at path: String = ".") throws -> String {
        try run(command, path)
    }

    static let live: Self = .init(run: { cmd, path in
        try ShellOut.shellOut(to: cmd, at: path)
    })
}


#if DEBUG
var Current: AppEnvironment = .live
#else
let Current: AppEnvironment = .live
#endif
