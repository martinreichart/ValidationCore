import base45_swift
import CocoaLumberjackSwift
import Gzip
#if canImport(UIKit)
import UIKit
#else
import Foundation
#endif
import CertLogic

/// Electronic Health Certificate Validation Core
///
/// This struct provides an interface for validating EHN Health certificates generated by https://dev.a-sit.at/certservice
public struct ValidationCore {
    private static let DEFAULT_TRUSTLIST_URL = "https://dgc.a-sit.at/ehn/cert/listv2"
    private static let DEFAULT_TRUSTLIST_SIGNATURE_URL = "https://dgc.a-sit.at/ehn/cert/sigv2"
    private static let DEFAULT_TRUSTLIST_TRUSTANCHOR = """
    MIIBJTCBy6ADAgECAgUAwvEVkzAKBggqhkjOPQQDAjAQMQ4wDAYDVQQDDAVFQy1N
    ZTAeFw0yMTA0MjMxMTI3NDhaFw0yMTA1MjMxMTI3NDhaMBAxDjAMBgNVBAMMBUVD
    LU1lMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE/OV5UfYrtE140ztF9jOgnux1
    oyNO8Bss4377E/kDhp9EzFZdsgaztfT+wvA29b7rSb2EsHJrr8aQdn3/1ynte6MS
    MBAwDgYDVR0PAQH/BAQDAgWgMAoGCCqGSM49BAMCA0kAMEYCIQC51XwstjIBH10S
    N701EnxWGK3gIgPaUgBN+ljZAs76zQIhAODq4TJ2qAPpFc1FIUOvvlycGJ6QVxNX
    EkhRcgdlVfUb
    """.replacingOccurrences(of: "\n", with: "")

    private static let DEFAULT_BUSINESSRULES_URL = "https://dgc.a-sit.at/ehn/rules/v1/bin"
    private static let DEFAULT_BUSINESSRULES_SIGNATURE_URL = "https://dgc.a-sit.at/ehn/rules/v1/sig"
    private static let DEFAULT_BUSINESSRULES_TRUSTANCHOR = """
    MIIBJTCBy6ADAgECAgUAwvEVkzAKBggqhkjOPQQDAjAQMQ4wDAYDVQQDDAVFQy1N
    ZTAeFw0yMTA0MjMxMTI3NDhaFw0yMTA1MjMxMTI3NDhaMBAxDjAMBgNVBAMMBUVD
    LU1lMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE/OV5UfYrtE140ztF9jOgnux1
    oyNO8Bss4377E/kDhp9EzFZdsgaztfT+wvA29b7rSb2EsHJrr8aQdn3/1ynte6MS
    MBAwDgYDVR0PAQH/BAQDAgWgMAoGCCqGSM49BAMCA0kAMEYCIQC51XwstjIBH10S
    N701EnxWGK3gIgPaUgBN+ljZAs76zQIhAODq4TJ2qAPpFc1FIUOvvlycGJ6QVxNX
    EkhRcgdlVfUb
    """.replacingOccurrences(of: "\n", with: "")

    private static let DEFAULT_VALUE_SETS_URL = "https://dgc.a-sit.at/ehn/values/v1/bin"
    private static let DEFAULT_VALUE_SETS_SIGNATURE_URL = "https://dgc.a-sit.at/ehn/values/v1/sig"
    private static let DEFAULT_VALUE_SETS_TRUSTANCHOR = """
    MIIBJTCBy6ADAgECAgUAwvEVkzAKBggqhkjOPQQDAjAQMQ4wDAYDVQQDDAVFQy1N
    ZTAeFw0yMTA0MjMxMTI3NDhaFw0yMTA1MjMxMTI3NDhaMBAxDjAMBgNVBAMMBUVD
    LU1lMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE/OV5UfYrtE140ztF9jOgnux1
    oyNO8Bss4377E/kDhp9EzFZdsgaztfT+wvA29b7rSb2EsHJrr8aQdn3/1ynte6MS
    MBAwDgYDVR0PAQH/BAQDAgWgMAoGCCqGSM49BAMCA0kAMEYCIQC51XwstjIBH10S
    N701EnxWGK3gIgPaUgBN+ljZAs76zQIhAODq4TJ2qAPpFc1FIUOvvlycGJ6QVxNX
    EkhRcgdlVfUb
    """.replacingOccurrences(of: "\n", with: "")

    private let PREFIX = "HC1:"

    private var completionHandler : ((ValidationResult) -> ())?
    #if canImport(UIKit)
    private var scanner : QrCodeScanner?
    #endif
    private let trustlistService : TrustlistService
    private let businessRulesService : BusinessRulesService
    private let valueSetsService : ValueSetsService
    private let dateService : DateService

    public init(trustlistService: TrustlistService? = nil,
                dateService: DateService? = nil,
                trustlistUrl: String? = nil,
                signatureUrl: String? = nil,
                trustAnchor : String? = nil,
                businessRulesService: BusinessRulesService? = nil,
                businessRulesUrl: String? = nil,
                businessRulesSignatureUrl: String? = nil,
                businessRulesTrustAnchor: String? = nil,
                valueSetsService: ValueSetsService? = nil,
                valueSetsUrl: String? = nil,
                valueSetsSignatureUrl: String? = nil,
                valueSetsTrustAnchor: String? = nil
    ) {
        let dateService = dateService ?? DefaultDateService()
        self.dateService = dateService
        self.trustlistService = trustlistService ?? DefaultTrustlistService(dateService: dateService, trustlistUrl: trustlistUrl ?? ValidationCore.DEFAULT_TRUSTLIST_URL, signatureUrl: signatureUrl ?? ValidationCore.DEFAULT_TRUSTLIST_SIGNATURE_URL, trustAnchor: trustAnchor ?? ValidationCore.DEFAULT_TRUSTLIST_TRUSTANCHOR)

        self.businessRulesService = businessRulesService ?? DefaultBusinessRulesService(dateService: dateService, businessRulesUrl: businessRulesUrl ?? ValidationCore.DEFAULT_BUSINESSRULES_URL, signatureUrl: businessRulesSignatureUrl ?? ValidationCore.DEFAULT_BUSINESSRULES_SIGNATURE_URL, trustAnchor: businessRulesTrustAnchor ?? ValidationCore.DEFAULT_BUSINESSRULES_TRUSTANCHOR)

        self.valueSetsService = valueSetsService ?? DefaultValueSetsService(dateService: dateService, valueSetsUrl: valueSetsUrl ?? ValidationCore.DEFAULT_VALUE_SETS_URL, signatureUrl: valueSetsSignatureUrl ?? ValidationCore.DEFAULT_VALUE_SETS_SIGNATURE_URL, trustAnchor: valueSetsTrustAnchor ?? ValidationCore.DEFAULT_VALUE_SETS_TRUSTANCHOR)

        DDLog.add(DDOSLogger.sharedInstance)
   }

    //MARK: - Public API
    
    #if canImport(UIKit)
    /// Instantiate a QR code scanner and validate the scannned EHN health certificate
    public mutating func validateQrCode(_ qrView : UIView, _ completionHandler: @escaping (ValidationResult) -> ()){
        self.completionHandler = completionHandler
        self.scanner = QrCodeScanner()
        scanner?.scan(qrView, self)
    }
    #endif
    
    /// Validate an Base45-encoded EHN health certificate
    public func validate(encodedData: String, _ completionHandler: @escaping (ValidationResult) -> ()) {
        DDLogInfo("Starting validation")
        guard let unprefixedEncodedString = removeScheme(prefix: PREFIX, from: encodedData) else {
            completionHandler(ValidationResult(isValid: false, metaInformation: nil, greenpass: nil, error: .INVALID_SCHEME_PREFIX))
            return
        }
        
        guard let decodedData = decode(unprefixedEncodedString) else {
            completionHandler(ValidationResult(isValid: false, metaInformation: nil, greenpass: nil, error: .BASE_45_DECODING_FAILED))
            return
        }
        DDLogDebug("Base45-decoded data: \(decodedData.humanReadable())")
        
        guard let decompressedData = decompress(decodedData) else {
            completionHandler(ValidationResult(isValid: false, metaInformation: nil, greenpass: nil, error: .DECOMPRESSION_FAILED))
            return
        }
        DDLogDebug("Decompressed data: \(decompressedData.humanReadable())")

        guard let cose = cose(from: decompressedData),
              let keyId = cose.keyId else {
            completionHandler(ValidationResult(isValid: false, metaInformation: nil, greenpass: nil, error: .COSE_DESERIALIZATION_FAILED))
            return
        }
        DDLogDebug("KeyID: \(keyId.encode())")
        
        guard let cwt = CWT(from: cose.payload),
              let euHealthCert = cwt.euHealthCert else {
            completionHandler(ValidationResult(isValid: false, metaInformation: nil, greenpass: nil, error: .CBOR_DESERIALIZATION_FAILED))
            return
        }
        
        guard cwt.isValid(using: dateService) else {
            completionHandler(ValidationResult(isValid: false, metaInformation: MetaInfo(from: cwt), greenpass: euHealthCert, error: .CWT_EXPIRED))
            return
        }

        trustlistService.key(for: keyId, cwt: cwt, keyType: euHealthCert.type) { result in
            switch result {
            case .success(let key):
                let isSignatureValid = cose.hasValidSignature(for: key)
                completionHandler(ValidationResult(isValid: isSignatureValid, metaInformation: MetaInfo(from: cwt), greenpass: euHealthCert, error: isSignatureValid ? nil : .SIGNATURE_INVALID))
            case .failure(let error): completionHandler(ValidationResult(isValid: false, metaInformation: MetaInfo(from: cwt), greenpass: euHealthCert, error: error))
            }
        }
    }

    public func validateBusinessRules(forCertificate certificate: EuHealthCert, validationClock: Date, issuedAt: Date, expiresAt: Date, countryCode: String, completionHandler: @escaping ([CertLogic.ValidationResult]) -> ()) {
        self.businessRulesService.businessRules { result in
            switch result {
            case .success(let rules):
                self.valueSetsService.valueSets { valueSetResult in
                    switch valueSetResult {
                    case .success(let valueSets):
                        let certLogicValueSets = valueSets.mapValues({ $0.valueSetValues.map({ $0.key})})

                        let engine = CertLogicEngine(schema: euDgcSchemaV1, rules: rules)
                        let filter = FilterParameter(validationClock: validationClock, countryCode: countryCode, certificationType: certificate.certificationType)
                        let certificatePayload = try! JSONEncoder().encode(certificate)
                        let payloadString = String(data: certificatePayload, encoding: .utf8)!

                        let result = engine.validate(filter: filter, external: ExternalParameter(validationClock: validationClock, valueSets: certLogicValueSets, exp: expiresAt, iat: issuedAt, issuerCountryCode: countryCode), payload: payloadString)

                        if result.count == 0 {
                            completionHandler([CertLogic.ValidationResult(rule: nil, result: .passed, validationErrors: nil)])
                        } else {
                            completionHandler(result)
                        }
                    case .failure(_):
                        completionHandler([CertLogic.ValidationResult(rule: nil, result: .fail, validationErrors: nil)])
                    }
                }
            case .failure(_):
                completionHandler([CertLogic.ValidationResult(rule: nil, result: .fail, validationErrors: nil)])
                break
            }
        }
    }

    public func updateTrustlist(completionHandler: @escaping (ValidationError?)->()) {
        trustlistService.updateDataIfNecessary(completionHandler: completionHandler)
    }

    //MARK: - Helper Functions

    /// Strips a given scheme prefix from the encoded EHN health certificate
    private func removeScheme(prefix: String, from encodedString: String) -> String? {
        guard encodedString.starts(with: prefix) else {
            DDLogError("Encoded data string does not seem to include scheme prefix: \(encodedString.prefix(prefix.count))")
            return nil
        }
        return String(encodedString.dropFirst(prefix.count))
    }
    
    /// Base45-decodes an EHN health certificate
    private func decode(_ encodedData: String) -> Data? {
        return try? encodedData.fromBase45()
    }
    
    /// Decompress the EHN health certificate using ZLib
    private func decompress(_ encodedData: Data) -> Data? {
        return try? encodedData.gunzipped()
    }

    /// Creates COSE structure from EHN health certificate
    private func cose(from data: Data) -> Cose? {
       return Cose(from: data)
    }
    
}

// MARK: - QrCodeReceiver
#if canImport(UIKit)
extension ValidationCore : QrCodeReceiver {
    public func canceled() {
        DDLogDebug("QR code scanning cancelled.")
        completionHandler?(ValidationResult(isValid: false, metaInformation: nil, greenpass: nil, error: .USER_CANCELLED))
    }
    
    /// Process the scanned EHN health certificate
    public func onQrCodeResult(_ result: String?) {
        guard let result = result,
              let completionHandler = self.completionHandler else {
            DDLogError("Cannot read QR code.")
            self.completionHandler?(ValidationResult(isValid: false, metaInformation: nil, greenpass: nil, error: .QR_CODE_ERROR))
            return
        }
        validate(encodedData: result, completionHandler)
    }
}
#endif


