@testable import App

import XCTest


class GithubTests: XCTestCase {
    
    func test_getHeader() throws {
        do { // without token
            Current.githubToken = { nil }
            XCTAssertEqual(Github.getHeaders, .init([("User-Agent", "SPI-Server")]))
        }
        do { // with token
            Current.githubToken = { "foobar" }
            XCTAssertEqual(Github.getHeaders, .init([
                ("User-Agent", "SPI-Server"),
                ("Authorization", "token foobar")
            ]))
        }
    }

    func test_Github_apiUri() throws {
        do {
            let pkg = Package(url: "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server.git")
            XCTAssertEqual(try Github.apiUri(for: pkg).string,
                           "https://api.github.com/repos/SwiftPackageIndex/SwiftPackageIndex-Server")
        }
        do {
            let pkg = Package(url: "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server")
            XCTAssertEqual(try Github.apiUri(for: pkg).string,
                           "https://api.github.com/repos/SwiftPackageIndex/SwiftPackageIndex-Server")
        }
    }

    func test_fetchRepository() throws {
        let pkg = Package(url: "https://github.com/foo/bar")
        let client = MockClient { resp in
            resp.status = .ok
            resp.body = makeBody("""
                    {
                    "default_branch": "master",
                    "forks_count": 1,
                    "stargazers_count": 2,
                    }
                    """)
        }
        let meta = try Github.fetchMetadata(client: client, package: pkg).wait()
        XCTAssertEqual(meta.defaultBranch, "master")
        XCTAssertEqual(meta.forksCount, 1)
        XCTAssertEqual(meta.stargazersCount, 2)
    }

    func test_fetchRepository_badUrl() throws {
        let pkg = Package(url: "https://foo/bar")
        let client = MockClient { resp in
            resp.status = .ok
        }
        XCTAssertThrowsError(try Github.fetchMetadata(client: client, package: pkg).wait()) {
            guard case AppError.invalidPackageUrl = $0 else {
                XCTFail("unexpected error: \($0.localizedDescription)")
                return
            }
        }
    }

    func test_fetchRepository_badData() throws {
        let pkg = Package(url: "https://github.com/foo/bar")
        let client = MockClient { resp in
            resp.status = .ok
            resp.body = makeBody("bad data")
        }
        XCTAssertThrowsError(try Github.fetchMetadata(client: client, package: pkg).wait()) {
            guard case DecodingError.dataCorrupted = $0 else {
                XCTFail("unexpected error: \($0.localizedDescription)")
                return
            }
        }
    }

    func test_fetchRepository_rateLimiting() throws {
        let pkg = Package(url: "https://github.com/foo/bar")
        let client = MockClient { resp in
            resp.status = .tooManyRequests
        }
        XCTAssertThrowsError(try Github.fetchMetadata(client: client, package: pkg).wait()) {
            guard case AppError.metadataRequestFailed(nil, .tooManyRequests, _) = $0 else {
                XCTFail("unexpected error: \($0.localizedDescription)")
                return
            }
        }
    }
}