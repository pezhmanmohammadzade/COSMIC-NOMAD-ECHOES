//
//  NASAService.swift
//  COSMIC NOMAD: ECHOES
//
//  Fetches Astronomy Picture of the Day (APOD) from NASA's API
//  and creates a Metal texture for use as a sky background.
//

import Metal
import UIKit
import Foundation

@MainActor
final class NASAService {
    
    private let apiKey = "gNldGt8k0ykgJT48kFlqxHTggwhvClDV3j2vCNac"
    private let device: MTLDevice
    
    // Cached texture
    private(set) var skyTexture: MTLTexture?
    private(set) var isLoading: Bool = false
    private(set) var lastError: String?
    
    // Track which seed we fetched for (avoid redundant fetches)
    private var lastFetchedSeed: UInt64?
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    // MARK: - Fetch APOD
    
    /// Fetch a random APOD image and create a Metal texture
    /// Uses a deterministic date based on planet seed so each planet gets a consistent sky
    func fetchSkyImage(forPlanetSeed seed: UInt64) {
        guard !isLoading else { return }
        guard lastFetchedSeed != seed else { return }  // Already fetched for this planet
        
        isLoading = true
        lastError = nil
        lastFetchedSeed = seed
        
        // Generate a deterministic date from seed for consistent planet sky
        // APOD archive starts June 16, 1995
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: 1995, month: 6, day: 16))!
        let endDate = calendar.date(from: DateComponents(year: 2024, month: 12, day: 31))!
        let totalDays = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 10000
        
        let dayOffset = Int(seed % UInt64(totalDays))
        let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate)!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: targetDate)
        
        let urlString = "https://api.nasa.gov/planetary/apod?api_key=\(apiKey)&date=\(dateString)&thumbs=true"
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            lastError = "Invalid URL"
            return
        }
        
        print("🌌 NASAService: Fetching APOD for date \(dateString)...")
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    handleError("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                    return
                }
                
                // Parse JSON
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    handleError("Invalid JSON response")
                    return
                }
                
                let mediaType = json["media_type"] as? String ?? "image"
                
                // Get image URL (use thumbnail for videos)
                let imageURLString: String?
                if mediaType == "video" {
                    imageURLString = json["thumbnail_url"] as? String
                } else {
                    // Try regular URL, fall back to thumbnail
                    imageURLString = json["url"] as? String
                }
                
                guard let imageURL = imageURLString, let imgURL = URL(string: imageURL) else {
                    handleError("No image URL in APOD response")
                    return
                }
                
                let title = json["title"] as? String ?? "Unknown"
                print("🌌 NASAService: Downloading '\(title)' (\(mediaType))")
                
                // Download image
                let (imageData, _) = try await URLSession.shared.data(from: imgURL)
                
                guard let uiImage = UIImage(data: imageData) else {
                    handleError("Failed to decode image data")
                    return
                }
                
                // Create Metal texture
                await MainActor.run {
                    self.skyTexture = self.createTexture(from: uiImage)
                    self.isLoading = false
                    
                    if self.skyTexture != nil {
                        print("🌌 NASAService: Sky texture created successfully (\(Int(uiImage.size.width))x\(Int(uiImage.size.height)))")
                    } else {
                        print("🌌 NASAService: Failed to create Metal texture")
                    }
                }
                
            } catch {
                handleError("Network error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Texture Creation
    
    private func createTexture(from image: UIImage) -> MTLTexture? {
        guard let cgImage = image.cgImage else { return nil }
        
        // Cap resolution for performance (max 2048)
        let maxSize = 2048
        let width = min(cgImage.width, maxSize)
        let height = min(cgImage.height, maxSize)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        texture.label = "NASA APOD Sky"
        
        // Draw image into RGBA bitmap context
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = bytesPerRow * height
        
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Upload to Metal texture
        texture.replace(
            region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                              size: MTLSize(width: width, height: height, depth: 1)),
            mipmapLevel: 0,
            withBytes: pixelData,
            bytesPerRow: bytesPerRow
        )
        
        return texture
    }
    
    // MARK: - Error Handling
    
    @MainActor
    private func handleError(_ message: String) {
        print("🌌 NASAService: \(message)")
        self.lastError = message
        self.isLoading = false
    }
}
