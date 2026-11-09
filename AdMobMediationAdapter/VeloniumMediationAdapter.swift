import Foundation
import UIKit
import GoogleMobileAds
import VeloniumSDK

@objc(VeloniumMediationAdapter)
public class VeloniumMediationAdapter: NSObject, GoogleMobileAds.MediationAdapter {
    
    // MARK: - Auto-Initialization
    
    // All static state below is only touched on the main thread.
    
    // Track if auto-initialization has been triggered
    private static var autoInitTriggered = false
    // Velonium.initializeSDK(...) has run (exactly once)
    private static var sdkInitialized = false
    // Load requests that arrived before initialization finished
    private static var pendingReadyBlocks: [() -> Void] = []
    // Fallback: initialize with cached/default values if configs never complete
    private static let initFallbackTimeout: TimeInterval = 6.0
    
    // MARK: - Properties
    
    // Adapters are retained to prevent deallocation during ad loading
    private var bannerAdapter: VeloniumAdMobBannerAdapter?
    private var interstitialAdapter: VeloniumAdMobInterstitialAdapter?
    private var rewardedAdapter: VeloniumAdMobRewardedAdapter?
    
    // Mediation units for fetching demand internally
    private var bannerMediationUnit: MediationBannerAdUnit?
    private var interstitialMediationUnit: MediationInterstitialAdUnit?
    private var rewardedMediationUnit: MediationRewardedAdUnit?
    
    // MARK: - GoogleMobileAds.MediationAdapter
    
    public static func networkExtrasClass() -> (any GoogleMobileAds.AdNetworkExtras.Type)? {
        return GoogleMobileAds.CustomEventExtras.self
    }
    
    public required override init() {
        super.init()
        // Trigger auto-initialization on first adapter instantiation
        Self.triggerAutoInitialization()
    }
    
    /// Trigger SDK auto-initialization (called once when adapter is first loaded)
    /// Can be called externally for early initialization.
    ///
    /// Never blocks: both configs load asynchronously (cached values complete immediately) and the
    /// SDK is initialized when both are done, or after `initFallbackTimeout` at the latest.
    @objc public static func triggerAutoInitialization() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { triggerAutoInitialization() }
            return
        }
        guard !autoInitTriggered else { return }
        autoInitTriggered = true
        
        // Load configs in parallel, asynchronously
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let remoteConfig = VeloniumRemoteConfig()
        let appConfig = VeloniumAppConfig.shared(bundleId: bundleId)
        
        let configGroup = DispatchGroup()
        
        configGroup.enter()
        remoteConfig.loadConfigAsync {
            configGroup.leave()
        }
        
        configGroup.enter()
        appConfig.loadConfigAsync {
            configGroup.leave()
        }
        
        configGroup.notify(queue: .main) {
            completeInitialization(remoteConfig: remoteConfig, appConfig: appConfig, bundleId: bundleId)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + initFallbackTimeout) {
            guard !sdkInitialized else { return }
            Log.warn("VeloniumMediationAdapter: Config loading timed out, using cached/default values")
            completeInitialization(remoteConfig: remoteConfig, appConfig: appConfig, bundleId: bundleId)
        }
    }
    
    /// Runs the SDK initialization exactly once (main thread), then flushes queued load requests.
    private static func completeInitialization(remoteConfig: VeloniumRemoteConfig,
                                               appConfig: VeloniumAppConfig,
                                               bundleId: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !sdkInitialized else { return }
        sdkInitialized = true
        
        let hostUrl = appConfig.getEndpointUrl()
        // Optional non-tracking twin of `endpoint`. The SDK picks between the two per bid request:
        // ATT authorized -> hostUrl, otherwise -> nonTrackingHostUrl (when configured).
        let nonTrackingHostUrl = appConfig.getNonTrackingEndpointUrl()
        let statusUrl = remoteConfig.statusUrl
        Velonium.shared.customStatusEndpoint = statusUrl
        
        Velonium.shared.logLevel = mapLogLevel(remoteConfig.logLevel)
        
        // Set source app (iTunes ID from S3 config, fallback to bundle)
        if let itunesId = appConfig.itunesId, !itunesId.isEmpty {
            Targeting.shared.sourceapp = itunesId
        } else {
            Targeting.shared.sourceapp = bundleId
        }
        
        // Initialize Velonium SDK with server URL
        do {
            let gadVersion = string(for: MobileAds.shared.versionNumber)
            print("Velonium SDK - initializeSDK()");
            if let nonTrackingHostUrl {
                do {
                    try Velonium.initializeSDK(serverURL: hostUrl, nonTrackingURLString: nonTrackingHostUrl, gadMobileAdsVersion: gadVersion, nil)
                } catch {
                    // Invalid endpointNonTracking must not break initialization: fall back to 1.0.5 behaviour.
                    Log.warn("VeloniumMediationAdapter: Invalid endpointNonTracking '\(nonTrackingHostUrl)', using endpoint for all requests")
                    try Velonium.initializeSDK(serverURL: hostUrl, gadMobileAdsVersion: gadVersion, nil)
                }
            } else {
                try Velonium.initializeSDK(serverURL: hostUrl, gadMobileAdsVersion: gadVersion, nil)
            }
          
        } catch { }
        
        let queued = pendingReadyBlocks
        pendingReadyBlocks = []
        queued.forEach { $0() }
    }
    
    /// Runs `block` on the main thread once the SDK is initialized: immediately if it already is,
    /// otherwise queued until initialization completes. Also makes sure initialization was started.
    static func whenReady(_ block: @escaping () -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { whenReady(block) }
            return
        }
        if sdkInitialized {
            block()
            return
        }
        pendingReadyBlocks.append(block)
        triggerAutoInitialization()
    }
    
    /// Map log level string to LogLevel object
    private static func mapLogLevel(_ levelString: String) -> LogLevel {
        switch levelString.uppercased() {
        case "DEBUG":
            return .debug
        case "VERBOSE":
            return .verbose
        case "INFO":
            return .info
        case "WARN", "WARNING":
            return .warn
        case "ERROR":
            return .error
        case "SEVERE":
            return .severe
        default:
            return .debug
        }
    }
    
    // MARK: - Versions
    
    public static func adSDKVersion() -> GoogleMobileAds.VersionNumber {
        return GoogleMobileAds.VersionNumber(majorVersion: 1, minorVersion: 0, patchVersion: 7)
    }
    
    public static func adapterVersion() -> GoogleMobileAds.VersionNumber {
        return GoogleMobileAds.VersionNumber(majorVersion: 1, minorVersion: 0, patchVersion: 7)
    }
    
    // MARK: - Ad Loaders
    
    public func loadBanner(
        for adConfiguration: GoogleMobileAds.MediationBannerAdConfiguration,
        completionHandler: @escaping GADMediationBannerLoadCompletionHandler
    ) {
        Self.applyChildDirectedSignals()
        // GMA calls adapters on the main thread: never block it. Bid work runs once the SDK is
        // initialized (immediately when it already is); GMA accepts a later completion call.
        Self.whenReady {
            self.performLoadBanner(for: adConfiguration, completionHandler: completionHandler)
        }
    }
    
    private func performLoadBanner(
        for adConfiguration: GoogleMobileAds.MediationBannerAdConfiguration,
        completionHandler: @escaping GADMediationBannerLoadCompletionHandler
    ) {
        // Get publisherId from app config (S3) - shared instance, already loaded by initialization
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let appConfig = VeloniumAppConfig.shared(bundleId: bundleId)
        
        guard let publisherId = appConfig.getOrtbStringValue("app.publisher.id") ?? VeloniumMediationAdapter.parsePublisherIdOrConfigId(from: adConfiguration.credentials.settings) else {
            let error = createError(code: -24, message: "Missing publisherId in app config file.")
            _ = completionHandler(nil, error)
            return
        }
        
        let size = adConfiguration.adSize.size
        let collector = BidCollector()
        
        bannerMediationUnit = MediationBannerAdUnit(
            configID: publisherId,
            size: CGSize(width: size.width, height: size.height),
            mediationDelegate: collector
        )
        
        // Set publisherId for schain (use the same value as configId)
        bannerMediationUnit?.setPublisherId(publisherId)
        
        // Set bidfloor if available (from AdMob UI parameter)
        if let bidfloor = Self.parseBidfloor(from: adConfiguration.credentials.settings) {
            bannerMediationUnit?.setBidfloor(bidfloor)
        }
        
        // Set tagid if available (from AdMob UI custom event parameter)
        if let tagid = Self.parseTagId(from: adConfiguration.credentials.settings) {
            bannerMediationUnit?.setTagId(tagid)
        }
        
        // Set gpid if available (from AdMob UI custom event parameter)
        if let gpid = Self.parseGpid(from: adConfiguration.credentials.settings) {
            bannerMediationUnit?.setGPID(gpid)
        }
        
        // Automatically detect and set ad position
        let detectedPosition = Self.detectAdPosition(
            adSize: size,
            topViewController: adConfiguration.topViewController
        )
        bannerMediationUnit?.adPosition = detectedPosition
        
        // If banner size is 320x50, add 300x50 as additional size
        if size.width == 320 && size.height == 50 {
            bannerMediationUnit?.additionalSizes = [CGSize(width: 300, height: 50)]
        }
                
        bannerMediationUnit?.fetchDemand { [weak self] result in
            guard let self = self else { return }
                        
            guard let bid = collector.collectedBid else {
                let error = self.createError(code: -25, message: "No banner bid returned from Velonium server.")
                _ = completionHandler(nil, error)
                self.bannerMediationUnit = nil
                return
            }
                        
            self.bannerAdapter = VeloniumAdMobBannerAdapter()
            self.bannerAdapter?.render(
                bid: bid,
                configId: publisherId,
                for: adConfiguration,
                completionHandler: completionHandler
            )
            self.bannerMediationUnit = nil
        }
    }
    
    public func loadInterstitial(
        for adConfiguration: GoogleMobileAds.MediationInterstitialAdConfiguration,
        completionHandler: @escaping GoogleMobileAds.GADMediationInterstitialLoadCompletionHandler
    ) {
        Self.applyChildDirectedSignals()
        // GMA calls adapters on the main thread: never block it. Bid work runs once the SDK is
        // initialized (immediately when it already is); GMA accepts a later completion call.
        Self.whenReady {
            self.performLoadInterstitial(for: adConfiguration, completionHandler: completionHandler)
        }
    }
    
    private func performLoadInterstitial(
        for adConfiguration: GoogleMobileAds.MediationInterstitialAdConfiguration,
        completionHandler: @escaping GoogleMobileAds.GADMediationInterstitialLoadCompletionHandler
    ) {
        // Get publisherId from app config (S3) - shared instance, already loaded by initialization
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let appConfig = VeloniumAppConfig.shared(bundleId: bundleId)
        
        guard let publisherId = appConfig.getOrtbStringValue("app.publisher.id") ?? VeloniumMediationAdapter.parsePublisherIdOrConfigId(from: adConfiguration.credentials.settings) else {
            let error = createError(code: -26, message: "Missing publisherId in app config file.")
            _ = completionHandler(nil, error)
            return
        }
        
        // Use dual-request approach - SDK sends BOTH banner and video requests separately
        // This matches Android implementation and provides better CPM comparison
        let bannerAdSize = CGSize(width: 320, height: 480)
        let bannerAdditionalSizes = [
            CGSize(width: 480, height: 320),  // Landscape
            CGSize(width: 300, height: 250),  // Medium rectangle
            CGSize(width: 728, height: 90),   // Leaderboard
            CGSize(width: 160, height: 600)    // Skyscraper
        ]
        
        MediationInterstitialAdUnit.fetchBothFormats(
            bannerConfigId: publisherId,
            videoConfigId: publisherId,
            bannerAdSize: bannerAdSize,
            bannerAdditionalSizes: bannerAdditionalSizes,
            videoMinDuration: 5,
            videoMaxDuration: 600
        ) { [weak self] winningBid in
            guard let self = self else { return }
            
            guard let bid = winningBid else {
                let error = self.createError(code: -27, message: "No bid returned from Velonium server.")
                _ = completionHandler(nil, error)
                self.interstitialMediationUnit = nil
                return
            }
        
            // Create adapter and render the winning bid
            self.interstitialAdapter = VeloniumAdMobInterstitialAdapter()
            self.interstitialAdapter?.render(
                bid: bid,
                configId: publisherId,
                for: adConfiguration,
                completionHandler: completionHandler
            )
            self.interstitialMediationUnit = nil
        }
    }
    
    public func loadRewardedAd(
        for adConfiguration: GoogleMobileAds.MediationRewardedAdConfiguration,
        completionHandler: @escaping GoogleMobileAds.GADMediationRewardedLoadCompletionHandler
    ) {
        Self.applyChildDirectedSignals()
        // GMA calls adapters on the main thread: never block it. Bid work runs once the SDK is
        // initialized (immediately when it already is); GMA accepts a later completion call.
        Self.whenReady {
            self.performLoadRewardedAd(for: adConfiguration, completionHandler: completionHandler)
        }
    }
    
    private func performLoadRewardedAd(
        for adConfiguration: GoogleMobileAds.MediationRewardedAdConfiguration,
        completionHandler: @escaping GoogleMobileAds.GADMediationRewardedLoadCompletionHandler
    ) {
        // Get publisherId from app config (S3) - shared instance, already loaded by initialization
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let appConfig = VeloniumAppConfig.shared(bundleId: bundleId)
        
        guard let publisherId = appConfig.getOrtbStringValue("app.publisher.id") ?? VeloniumMediationAdapter.parsePublisherIdOrConfigId(from: adConfiguration.credentials.settings) else {
            let error = createError(code: -28, message: "Missing publisherId in app config file.")
            _ = completionHandler(nil, error)
            return
        }
        
        let collector = BidCollector()
        
        rewardedMediationUnit = MediationRewardedAdUnit(
            configId: publisherId,
            mediationDelegate: collector
        )
        
        // Set publisherId for schain (use the same value as configId)
        rewardedMediationUnit?.setPublisherId(publisherId)
        
        // Set bidfloor if available (from AdMob UI parameter)
        if let bidfloor = Self.parseBidfloor(from: adConfiguration.credentials.settings) {
            rewardedMediationUnit?.setBidfloor(bidfloor)
        }
        
        // Set tagid if available (from AdMob UI custom event parameter)
        if let tagid = Self.parseTagId(from: adConfiguration.credentials.settings) {
            rewardedMediationUnit?.setTagId(tagid)
        }
        
        // Set gpid if available (from AdMob UI custom event parameter)
        if let gpid = Self.parseGpid(from: adConfiguration.credentials.settings) {
            rewardedMediationUnit?.setGPID(gpid)
        }
        
        rewardedMediationUnit?.fetchDemand { [weak self] result in
            guard let self = self else { return }
            
            
            guard let bid = collector.collectedBid else {
                let error = self.createError(code: -29, message: "No bid returned from Velonium server.")
                _ = completionHandler(nil, error)
                self.rewardedMediationUnit = nil
                return
            }
            
            
            self.rewardedAdapter = VeloniumAdMobRewardedAdapter()
            self.rewardedAdapter?.render(
                bid: bid,
                configId: publisherId,
                for: adConfiguration,
                completionHandler: completionHandler
            )
            self.rewardedMediationUnit = nil
        }
    }
    
    public func loadNativeAd(
        for adConfiguration: GoogleMobileAds.MediationNativeAdConfiguration,
        completionHandler: @escaping GoogleMobileAds.GADMediationNativeLoadCompletionHandler
    ) {
        let error = createError(code: -30, message: "Native ads not supported.")
        _ = completionHandler(nil, error)
    }
    
    public func loadRewardedInterstitialAd(
        for adConfiguration: GoogleMobileAds.MediationRewardedAdConfiguration,
        completionHandler: @escaping GoogleMobileAds.GADMediationRewardedLoadCompletionHandler
    ) {
        let error = createError(code: -31, message: "Rewarded interstitial not supported.")
        _ = completionHandler(nil, error)
    }
}

// MARK: - Private Helpers

private extension VeloniumMediationAdapter {

    // MARK: - COPPA / child-directed signals

    /// Mirrors Google's child-directed / under-age-of-consent tags into Velonium's COPPA flag
    /// before each bid request is built. AdMob/Unity publishers have no Velonium API, so these
    /// tags are the only signal available. GMA 12+ no longer exposes `childDirectedTreatment`
    /// on the mediation ad configuration, so the global request configuration is the source.
    ///   - child-directed == true OR under-age-of-consent == true -> COPPA on
    ///   - otherwise child-directed == false                       -> COPPA off
    ///   - otherwise (unspecified)                                 -> leave the current setting untouched
    static func applyChildDirectedSignals() {
        let requestConfiguration = GoogleMobileAds.MobileAds.shared.requestConfiguration
        if let coppa = coppaValue(
            childDirectedTreatment: requestConfiguration.tagForChildDirectedTreatment,
            underAgeOfConsent: requestConfiguration.tagForUnderAgeOfConsent
        ) {
            Targeting.shared.subjectToCOPPA = coppa
        }
    }

    /// Pure mapping (nil = leave untouched); kept separate so it can be unit tested.
    static func coppaValue(childDirectedTreatment: NSNumber?, underAgeOfConsent: NSNumber?) -> Bool? {
        if childDirectedTreatment?.boolValue == true || underAgeOfConsent?.boolValue == true {
            return true
        }
        if let childDirectedTreatment = childDirectedTreatment {
            return childDirectedTreatment.boolValue
        }
        return nil
    }
    
    static func parsePublisherId(from configuration: GoogleMobileAds.MediationServerConfiguration) -> String? {
        for creds in configuration.credentials {
            if let publisherId = parsePublisherId(from: creds.settings) {
                return publisherId
            }
        }
        return nil
    }
    
    static func parsePublisherId(from settings: [String: Any]) -> String? {
        // First try to get from app config (S3) - this is now the primary source.
        // Uses the shared instance loaded during initialization (no network I/O here).
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let appConfig = VeloniumAppConfig.shared(bundleId: bundleId)
        if let publisherId = appConfig.getOrtbStringValue("app.publisher.id"), !publisherId.isEmpty {
            return publisherId
        }
        
        // Fallback: Try to get from AdMob UI (for backward compatibility only)
        if let parameter = settings["parameter"] as? String,
           let data = parameter.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let pid = json["publisherId"] as? String { return pid }
            if let acc = json["accountId"] as? String { return acc }
        }
        
        if let pid = settings["publisherId"] as? String { return pid }
        if let acc = settings["accountId"] as? String { return acc }
        
        return nil
    }
    
    /// Parses publisherId (primary) or configId (fallback) from AdMob settings.
    /// Since publisherId and configId are the same, this tries publisherId first, then configId.
    static func parsePublisherIdOrConfigId(from settings: [String: Any]) -> String? {
        // First try publisherId (primary)
        if let publisherId = parsePublisherId(from: settings) {
            return publisherId
        }
        
        // Fallback to configId (for backward compatibility)
        return parseConfigId(from: settings)
    }
    
    static func parseBidfloor(from settings: [String: Any]) -> Double? {
        // Try parsing from JSON parameter - look for "ecpm" in AdMob UI (more user-friendly)
        if let parameter = settings["parameter"] as? String,
           let data = parameter.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // First try "ecpm" (AdMob UI friendly name)
            if let bidfloor = json["ecpm"] as? Double { return bidfloor }
            if let bidfloor = json["ecpm"] as? NSNumber { return bidfloor.doubleValue }
            // Fallback to "bidfloor" for backward compatibility
            if let bidfloor = json["bidfloor"] as? Double { return bidfloor }
            if let bidfloor = json["bidfloor"] as? NSNumber { return bidfloor.doubleValue }
        }
        
        // Try direct key - look for "ecpm" first (AdMob UI friendly name)
        if let bidfloor = settings["ecpm"] as? Double { return bidfloor }
        if let bidfloor = settings["ecpm"] as? NSNumber { return bidfloor.doubleValue }
        if let bidfloorStr = settings["ecpm"] as? String, let bidfloor = Double(bidfloorStr) {
            return bidfloor
        }
        // Fallback to "bidfloor" for backward compatibility
        if let bidfloor = settings["bidfloor"] as? Double { return bidfloor }
        if let bidfloor = settings["bidfloor"] as? NSNumber { return bidfloor.doubleValue }
        if let bidfloorStr = settings["bidfloor"] as? String, let bidfloor = Double(bidfloorStr) {
            return bidfloor
        }
        
        // Fallback: Try to get from app config (loaded from S3 during initialization)
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let appConfig = VeloniumAppConfig.shared(bundleId: bundleId)
        if let bidfloorStr = appConfig.getOrtbStringValue("imp.0.bidfloor"),
           let bidfloor = Double(bidfloorStr),
           bidfloor > 0 {
            return bidfloor
        }
        
        // Note: AdMob's "Network eCPM" from ad unit mapping UI is not automatically passed
        // to the adapter. It's only used for waterfall ordering. You need to include it
        // in the custom parameters (as "ecpm" or "bidfloor") if you want to use it.
        
        // Default to 0.2 if no eCPM is specified in parameters
        return 0.2
    }

    
    /// Parses configId from AdMob settings (used as fallback when publisherId is not available).
    static func parseConfigId(from settings: [String: Any]) -> String? {
        // Try parsing from JSON parameter
        if let parameter = settings["parameter"] as? String,
           let data = parameter.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let configId = json["configId"] as? String {
            return configId
        }
        
        // Try direct key
        if let configId = settings["configId"] as? String {
            return configId
        }
        
        return nil
    }
    
    /// Parses tagid from AdMob UI custom event parameter.
    static func parseTagId(from settings: [String: Any]) -> String? {
        // Try parsing from JSON parameter
        if let parameter = settings["parameter"] as? String,
           let data = parameter.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let tagid = json["tagid"] as? String, !tagid.isEmpty {
                return tagid
            }
        }
        
        // Try direct key
        if let tagid = settings["tagid"] as? String, !tagid.isEmpty {
            return tagid
        }
        
        return nil
    }
    
    /// Parses gpid (Global Placement ID) from AdMob UI custom event parameter.
    static func parseGpid(from settings: [String: Any]) -> String? {
        // Try parsing from JSON parameter
        if let parameter = settings["parameter"] as? String,
           let data = parameter.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let gpid = json["gpid"] as? String, !gpid.isEmpty {
                return gpid
            }
        }
        
        // Try direct key
        if let gpid = settings["gpid"] as? String, !gpid.isEmpty {
            return gpid
        }
        
        return nil
    }
    
    /// Parses appid (iTunes ID, numeric) from app config (S3).
    /// This is used to construct the App Store URL.
    /// No longer reads from AdMob UI - only from app config file.
    static func parseAppId(from settings: [String: Any]) -> String? {
        // Get from app config (S3) - this is now the primary source (shared, already loaded)
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let appConfig = VeloniumAppConfig.shared(bundleId: bundleId)
        if let itunesId = appConfig.itunesId, !itunesId.isEmpty {
            return itunesId
        }
        
        // Fallback: Try to get from AdMob UI (for backward compatibility only)
        if let parameter = settings["parameter"] as? String,
           let data = parameter.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Try as string first
            if let appid = json["appid"] as? String, !appid.isEmpty {
                return appid
            }
            // Try as number
            if let appidNum = json["appid"] as? NSNumber {
                return appidNum.stringValue
            }
        }
        
        // Try direct key
        if let appid = settings["appid"] as? String, !appid.isEmpty {
            return appid
        }
        if let appidNum = settings["appid"] as? NSNumber {
            return appidNum.stringValue
        }
        
        return nil
    }
    
    /// Automatically detects ad position based on banner size and view hierarchy.
    /// Uses heuristics based on common banner placement patterns.
    /// OpenRTB pos values: 0=Unknown, 1=AboveFold, 3=BelowFold, 4=Header, 5=Footer, 6=Sidebar, 7=FullScreen
    static func detectAdPosition(
        adSize: CGSize,
        topViewController: UIViewController?
    ) -> AdPosition {
        // Try to detect from view hierarchy if available
        if let viewController = topViewController,
           let view = viewController.view,
           let window = view.window {
            // Get the view's position in the window
            let viewFrame = view.convert(view.bounds, to: window)
            let screenHeight = window.bounds.height
            let viewCenterY = viewFrame.midY
            
            // Header: Top 10% of screen
            if viewFrame.minY <= screenHeight * 0.1 {
                return .header // 4
            }
            
            // Footer: Bottom 10% of screen
            if viewFrame.maxY >= screenHeight * 0.9 {
                return .footer // 5
            }
            
            // Above fold: Top 50% of screen
            if viewCenterY < screenHeight * 0.5 {
                return .aboveTheFold // 1
            }
            
            // Below fold: Bottom 50% of screen
            return .belowTheFold // 3
        }
        
        // Fallback to heuristics based on banner size
        let width = adSize.width
        let height = adSize.height
        
        // Leaderboard (728x90) is typically at top (header)
        if width == 728 && height == 90 {
            return .header // 4
        }
        
        // Standard banners (320x50, 300x50) are often at top or bottom
        // Default to header (top) as it's more common
        if (width == 320 && height == 50) || (width == 300 && height == 50) {
            return .header // 4
        }
        
        // Medium rectangle (300x250) is typically in content (above fold)
        if width == 300 && height == 250 {
            return .aboveTheFold // 1
        }
        
        // Skyscraper (160x600) is typically sidebar
        if width == 160 && height == 600 {
            return .sidebar // 6
        }
        
        // Default to unknown if we can't determine
        return .unknown // 0
    }
    
    func createError(code: Int, message: String) -> NSError {
        return NSError(
            domain: "com.velonium.adapter",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

// MARK: - Bid Collector

/// Helper class to collect bids from MediationAdUnit fetchDemand calls
private final class BidCollector: VeloniumMediationDelegate {
    
    var collectedBid: Bid?
    private let dummyView = UIView()
    
    func setUpAdObject(with values: [String : Any]) -> Bool {
        if let bid = values[PBMMediationAdUnitBidKey] as? Bid {
            collectedBid = bid
            return true
        }
        return false
    }
    
    func cleanUpAdObject() {
        collectedBid = nil
    }
    
    func getAdView() -> UIView? {
        return dummyView
    }
}
