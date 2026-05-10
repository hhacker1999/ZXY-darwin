//
//  LibraryCustomizationSection.swift
//  LearnSwift
//
//  Lets the user reorder, rename, add and remove library rows that show on
//  the home screen, then save them via `updateProfileList`.
//

import SwiftUI

struct LibraryCustomizationSection: View {
    @Bindable var vm: SettingsViewModel
    @State private var editingItem: EditingItem?
    @State private var showAddSheet = false

    var body: some View {
        SettingsCard {
            header

            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)

            if vm.libraryItems.isEmpty {
                Text("No library rows yet — add one to populate your home page.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.Colors.elementSubtle)
                    .padding(AppTheme.Spacing.md)
            } else {
                ForEach(Array(vm.libraryItems.enumerated()), id: \.offset) { index, item in
                    LibraryItemRow(
                        item: item,
                        isFirst: index == 0,
                        isLast: index == vm.libraryItems.count - 1,
                        onMoveUp: { moveUp(index) },
                        onMoveDown: { moveDown(index) },
                        onEdit: { editingItem = EditingItem(index: index, name: item.name) },
                        onDelete: { vm.deleteLibraryItem(at: index) }
                    )

                    if index < vm.libraryItems.count - 1 {
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
                    }
                }
            }
        }
        .sheet(item: $editingItem) { editing in
            LibraryItemEditDialog(
                title: "Rename row",
                initialName: editing.name,
                onSave: { newName in
                    if let item = vm.libraryItems[safe: editing.index] {
                        let updated = LibraryItem(name: newName, filter: item.filter)
                        vm.updateLibraryItem(at: editing.index, with: updated)
                    }
                    editingItem = nil
                },
                onCancel: { editingItem = nil }
            )
        }
        .sheet(isPresented: $showAddSheet) {
            LibraryItemEditDialog(
                title: "Add a new row",
                initialName: "",
                onSave: { newName in
                    let trimmed = newName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let item = LibraryItem(
                        name: trimmed,
                        filter: Filter(type: "internal", items: 15, isMovie: true, traktUrl: nil)
                    )
                    vm.addLibraryItem(item)
                    showAddSheet = false
                },
                onCancel: { showAddSheet = false }
            )
        }
    }

    private var header: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Text("Home page rows")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.Colors.elementSubtle)

            Spacer()

            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.elementWhite)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Add a row")

            Button {
                Task { await vm.saveLibraryItems() }
            } label: {
                HStack(spacing: 6) {
                    if vm.isSavingLibrary {
                        ProgressView().tint(AppTheme.Colors.buttonPrimaryLabel).controlSize(.small)
                    }
                    Text(vm.hasLibraryChanges ? "Save Changes" : "Saved")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(
                            vm.hasLibraryChanges
                                ? AppTheme.Colors.buttonPrimaryLabel
                                : AppTheme.Colors.elementSubtle
                        )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            vm.hasLibraryChanges
                                ? AppTheme.Colors.buttonPrimary
                                : Color.white.opacity(0.06)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!vm.hasLibraryChanges || vm.isSavingLibrary)
        }
        .padding(AppTheme.Spacing.md)
    }

    private func moveUp(_ index: Int) {
        guard index > 0 else { return }
        vm.moveLibraryItem(from: IndexSet(integer: index), to: index - 1)
    }

    private func moveDown(_ index: Int) {
        guard index < vm.libraryItems.count - 1 else { return }
        // SwiftUI's move expects the destination to be the new position
        // _after_ the array has been reduced (i.e. index + 2).
        vm.moveLibraryItem(from: IndexSet(integer: index), to: index + 2)
    }
}

private struct EditingItem: Identifiable {
    let id = UUID()
    let index: Int
    let name: String
}

// MARK: ── Item row ──────────────────────────────────────────────────
private struct LibraryItemRow: View {
    let item: LibraryItem
    let isFirst: Bool
    let isLast: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: item.filter.isMovie ? "film" : "tv")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.Colors.elementWhite)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.elementWhite)
                Text(libraryItemSubtitle(item))
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.elementMuted)
            }

            Spacer()

            HStack(spacing: 6) {
                IconButton(icon: "arrow.up", enabled: !isFirst, action: onMoveUp)
                IconButton(icon: "arrow.down", enabled: !isLast, action: onMoveDown)
                IconButton(icon: "pencil", enabled: true, action: onEdit)
                IconButton(
                    icon: "trash",
                    enabled: true,
                    tint: AppTheme.Colors.error,
                    action: onDelete
                )
            }
        }
        .padding(AppTheme.Spacing.md)
    }

    private func libraryItemSubtitle(_ item: LibraryItem) -> String {
        var parts: [String] = []
        parts.append(item.filter.isMovie ? "Movies" : "Shows")
        if !item.filter.type.isEmpty {
            parts.append(item.filter.type.capitalized)
        }
        if !item.filter.sort.isEmpty {
            parts.append(item.filter.sort.capitalized)
        }
        return parts.joined(separator: " · ")
    }
}

private struct IconButton: View {
    let icon: String
    let enabled: Bool
    var tint: Color = AppTheme.Colors.elementWhite
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(enabled ? tint : AppTheme.Colors.elementMuted.opacity(0.6))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(enabled ? 0.06 : 0.02))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: ── Edit dialog ───────────────────────────────────────────────
private struct LibraryItemEditDialog: View {
    let title: String
    let initialName: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var nameText: String

    init(title: String, initialName: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self.initialName = initialName
        self.onSave = onSave
        self.onCancel = onCancel
        _nameText = State(initialValue: initialName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text(title)
                .font(AppTheme.Typography.headingMedium)
                .foregroundStyle(AppTheme.Colors.elementWhite)

            TextField("Row name", text: $nameText)
                .textFieldStyle(.plain)
                .font(AppTheme.Typography.bodyMedium)
                .foregroundStyle(AppTheme.Colors.elementWhite)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            HStack(spacing: AppTheme.Spacing.sm) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(AppTheme.Typography.labelMedium)
                        .foregroundStyle(AppTheme.Colors.elementWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onSave(nameText)
                } label: {
                    Text("Save")
                        .font(AppTheme.Typography.labelMedium)
                        .foregroundStyle(AppTheme.Colors.buttonPrimaryLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppTheme.Colors.buttonPrimary)
                        )
                }
                .buttonStyle(.plain)
                .disabled(nameText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(minWidth: 360)
        .background(AppTheme.Colors.backgroundTertiary)
        .preferredColorScheme(.dark)
    }
}

// MARK: ── Array safe-subscript ──────────────────────────────────────
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
