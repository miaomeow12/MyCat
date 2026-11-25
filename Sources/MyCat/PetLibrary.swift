import Foundation

enum PetSpecies: String, Codable, CaseIterable {
    case cat, dog
    var title: String { self == .cat ? "猫咪" : "狗狗" }
    var english: String { self == .cat ? "cat" : "dog" }
    var icon: String { self == .cat ? "🐱" : "🐶" }
}
struct SavedPet: Codable, Equatable {
    let id: UUID
    let name: String
    let species: PetSpecies
    var fileName: String { id.uuidString + ".png" }
}
/// Local user-generated pets only. No network, credentials, or bundled artwork in this store.
final class PetLibrary {
    private struct State: Codable {
        var pets: [SavedPet] = []
        var activeID: UUID?
    }
    let directory: URL
    private var state: State
    private var manifest: URL { directory.appendingPathComponent("pets.json") }
    var pets: [SavedPet] { state.pets }
    var active: SavedPet? { state.pets.first { $0.id == state.activeID } }
    init(directory: URL) throws {
        self.directory = directory
        let url = directory.appendingPathComponent("pets.json")
        if FileManager.default.fileExists(atPath: url.path) {
            state = try JSONDecoder().decode(State.self, from: Data(contentsOf: url))
            guard Set(state.pets.map(\.id)).count == state.pets.count,
                  state.activeID == nil || state.pets.contains(where: { $0.id == state.activeID }) else {
                throw CocoaError(.fileReadCorruptFile)
            }
        } else { state = State() }
    }
    private func persist(_ next: State) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: manifest, options: .atomic)
        state = next
    }
    @discardableResult
    func save(data: Data, name: String, species: PetSpecies) throws -> SavedPet {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
        let record = SavedPet(id: UUID(), name: clean.isEmpty ? "我的" + species.title : String(clean.prefix(60)), species: species)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(record.fileName)
        try data.write(to: url, options: .atomic)
        var next = state
        next.pets.append(record)
        next.activeID = record.id
        do { try persist(next) }
        catch { try? FileManager.default.removeItem(at: url); throw error }
        return record
    }
    func data(for pet: SavedPet) throws -> Data {
        guard state.pets.contains(where: { $0.id == pet.id }) else { throw CocoaError(.fileNoSuchFile) }
        return try Data(contentsOf: directory.appendingPathComponent(pet.fileName))
    }
    func select(_ id: UUID?) throws {
        guard id == nil || state.pets.contains(where: { $0.id == id }) else { throw CocoaError(.fileNoSuchFile) }
        var next = state
        next.activeID = id
        try persist(next)
    }
    func migrateLegacyIfNeeded(_ data: Data) throws {
        guard !FileManager.default.fileExists(atPath: manifest.path) else { return }
        try save(data: data, name: "原来的猫咪", species: .cat)
    }
}
