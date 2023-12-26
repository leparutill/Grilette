import SwiftUI
import UIKit

struct Note: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var content: String
    var date: Date = Date()
    var lastModified: Date = Date()
    var imageData: Data?
    var isPinned: Bool = false
}

class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = []

    init() {
        loadNotes()
    }

    func loadNotes() {
        notes = UserDefaults.standard.object([Note].self, forKey: "notes")?.sorted(by: sortingCriteria) ?? []
    }

    func addOrUpdateNote(_ note: Note) {
        guard !note.title.isEmpty && !note.content.isEmpty else { return }
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.append(note)
        }
        sortNotes()
    }

    func pinNote(_ note: Note) {
        if let index = notes.firstIndex(of: note) {
            notes[index].isPinned.toggle()
            sortNotes()
        }
    }

    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        saveNotes()
    }

    private func sortNotes() {
        notes.sort(by: sortingCriteria)
        saveNotes()
    }

    private func sortingCriteria(_ note1: Note, _ note2: Note) -> Bool {
        if note1.isPinned != note2.isPinned {
            return note1.isPinned && !note2.isPinned
        }
        return note1.date > note2.date
    }

    func saveNotes() {
        UserDefaults.standard.set(object: notes, forKey: "notes")
    }
}

extension UserDefaults {
    func set<T: Encodable>(object: T, forKey key: String) {
        if let encoded = try? JSONEncoder().encode(object) {
            set(encoded, forKey: key)
        }
    }

    func object<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

extension NotesViewModel {
    func searchNotes(matching searchText: String) -> [Note] {
        if searchText.isEmpty {
            return notes
        } else {
            return notes.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

class AppSettings: ObservableObject {
    @Published var isDarkMode: Bool = UserDefaults.standard.bool(forKey: "isDarkMode") {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
}

struct ContentView: View {
    @StateObject var viewModel = NotesViewModel()
    @EnvironmentObject var appSettings: AppSettings
    @State private var showingSheet = false
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            Group {
                if viewModel.notes.isEmpty {
                    emptyStateView
                } else {
                    notesListView
                }
            }
            .navigationBarTitle("Grilette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        self.showingSheet = true
                    }) {
                        Image(systemName: "plus")
                    }

                    Menu {
                        Button(action: {
                            appSettings.isDarkMode.toggle()
                        }) {
                            Label(appSettings.isDarkMode ? "Aydınlık Mod" : "Karanlık Mod", systemImage: "moon.fill")
                        }
                        Button("Import Notes", action: {
                            // İçe aktarma işlevi
                        })
                        Button("Export Notes", action: {
                            // Dışa aktarma işlevi
                        })
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSheet) {
                NewNoteView(viewModel: viewModel, showingSheet: $showingSheet)
                    .environment(\.colorScheme, appSettings.isDarkMode ? .dark : .light)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Ara")
        }
        .environment(\.colorScheme, appSettings.isDarkMode ? .dark : .light)
    }

    private var emptyStateView: some View {
        HStack {
            Image("github-mark")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 25)
            
            Link("@leparutill", destination: URL(string: "https://github.com/leparutill")!)
                .foregroundStyle(.secondary)
                .font(.body)
        }
    }

    private var notesListView: some View {
        List {
            ForEach(viewModel.searchNotes(matching: searchText)) { note in
                        NavigationLink(destination: NoteDetailView(note: note, viewModel: viewModel)) {
                            HStack {
                        if let imageData = note.imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        }
                        VStack(alignment: .leading) {
                            Text(note.title)
                                .font(.headline)
                            Text(note.content)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                                Spacer()
                                Text(note.date, formatter: DateFormatter.hourMinute)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                        if note.isPinned {
                            Image(systemName: "pin.circle")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if note.isPinned {
                        Button("Çıkar") {
                            viewModel.pinNote(note)
                        }
                        .tint(.orange)
                    } else {
                        Button("Sabitle") {
                            viewModel.pinNote(note)
                        }
                        .tint(.blue)
                    }
                    Button(role: .destructive) {
                        viewModel.deleteNote(note)
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
            }
        }
    }
}

extension DateFormatter {
    static let hourMinute: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MM/dd/yyyy HH:mm"
        return formatter
    }()
}

struct NewNoteView: View {
    @ObservedObject var viewModel: NotesViewModel
    @Binding var showingSheet: Bool
    @State private var title = ""
    @State private var content = ""
    @State private var image: UIImage?
    @State private var showingImagePicker = false

    var body: some View {
        NavigationView {
            Form {
                if image != nil {
                    Image(uiImage: image!)
                        .resizable()
                        .scaledToFit()
                }
                Button("Select Image") {
                    showingImagePicker = true
                }
                
                Section("NOTE TITLE") {
                    TextField("",text: $title)
                        .autocorrectionDisabled()
                }
                
                Section("NOTE CONTENT") {
                    TextEditor(text: $content)
                        .autocorrectionDisabled()
                        .frame(minHeight: 300)
                }
            }
            .navigationBarTitle("Create New Note", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    showingSheet = false
                },
                trailing: Button("Save") {
                    let newNote = Note(title: title, content: content, imageData: image?.jpegData(compressionQuality: 1.0))
                    viewModel.addOrUpdateNote(newNote)
                    showingSheet = false
                }
            )
            .sheet(isPresented: $showingImagePicker, content: {
                ImagePicker(image: $image)
            })
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }

            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct NoteDetailView: View {
    var note: Note
    @ObservedObject var viewModel: NotesViewModel
    @EnvironmentObject var appSettings: AppSettings
    @State private var showingEditSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if let imageData = note.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }
                
                Text(note.content)
                    .padding()
                                
                VStack(alignment: .leading) {
                    Text("Creation: \(note.date, formatter: DateFormatter.fullDateTime)")
                    Text("Regulation: \(note.lastModified, formatter: DateFormatter.fullDateTime)")
                }.padding(.horizontal)
                    .font(.caption)
                            
            }
        }
        .navigationBarTitle(note.title, displayMode: .inline)
        .navigationBarItems(trailing: Button(action: {
            self.showingEditSheet = true
        }) {
            Image(systemName: "square.and.pencil")
        })
        .sheet(isPresented: $showingEditSheet) {
            EditNoteView(note: note, viewModel: viewModel, showingSheet: $showingEditSheet)
                .environment(\.colorScheme, appSettings.isDarkMode ? .dark : .light)
        }
    }
}

struct EditNoteView: View {
    var note: Note
    @ObservedObject var viewModel: NotesViewModel
    @Binding var showingSheet: Bool
    @State private var title: String
    @State private var content: String
    @State private var image: UIImage?
    @State private var showingImagePicker = false

    init(note: Note, viewModel: NotesViewModel, showingSheet: Binding<Bool>) {
        self.note = note
        self.viewModel = viewModel
        _showingSheet = showingSheet
        _title = State(initialValue: note.title)
        _content = State(initialValue: note.content)
        _image = State(initialValue: note.imageData != nil ? UIImage(data: note.imageData!) : nil)
    }

    var body: some View {
        NavigationView {
            Form {
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }
                
                Button("Select Image") {
                    showingImagePicker = true
                }
                
                Section("NOTE TITLE") {
                    TextField("", text: $title)
                        .autocorrectionDisabled()
                }
                
                Section("NOTE CONTENT") {
                    TextEditor(text: $content)
                        .autocorrectionDisabled()
                        .frame(minHeight: 300)
                }
                
            }
            .navigationBarTitle("Edit Note", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    showingSheet = false
                },
                trailing: Button("Save") {
                    let updatedNote = Note(id: note.id, title: title, content: content, date: note.date, imageData: image?.jpegData(compressionQuality: 1.0), isPinned: note.isPinned)
                    viewModel.addOrUpdateNote(updatedNote)
                    showingSheet = false
                }
            )
            .sheet(isPresented: $showingImagePicker, content: {
                ImagePicker(image: $image)
            })
        }
    }
}

@main
struct GriletteApp: App {
    @StateObject var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
        }
    }
}
