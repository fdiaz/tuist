import Foundation
import HTTPTypes
import OpenAPIRuntime

#if canImport(TuistSupport)
    import TuistSupport
#endif

enum CloudClientOutputWarningsMiddlewareError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .couldntConvertToData:
            "We couldn't convert Tuist warnings into a data instance"
        case .invalidSchema:
            "The Tuist warnings returned by the server have an unexpected schema"
        }
    }

    case couldntConvertToData
    case invalidSchema
}

/// A middleware that gets any warning returned in a "x-cloud-warning" header
/// and outputs it to the user.
struct ServerClientOutputWarningsMiddleware: ClientMiddleware {
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let (response, body) = try await next(request, body, baseURL)
        guard let warnings = response.headerFields.first(where: {
            $0.name.canonicalName == "x-tuist-cloud-warnings"
        })?.value
        else {
            return (response, body)
        }
        guard let warningsData = warnings.data(using: .utf8),
              let data = Data(base64Encoded: warningsData)
        else {
            throw CloudClientOutputWarningsMiddlewareError.couldntConvertToData
        }

        guard let json = try JSONSerialization
            .jsonObject(with: data) as? [String]
        else {
            throw CloudClientOutputWarningsMiddlewareError.invalidSchema
        }

        #if canImport(TuistSupport)
            json.forEach { AlertController.current.warning(.alert("\($0)")) }
        #endif

        return (response, body)
    }
}
