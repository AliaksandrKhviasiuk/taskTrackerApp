//
//  ContentView.swift
//  TaskTrackerApp
//
//  Created by Aliaksandr Khviasiuk on 09/08/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = TaskListViewModel(storage: FileTaskStore())
    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @State private var editingTask: TaskItem?
    @FocusState private var isTitleFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isAddingTask {
                    addTaskRow
                }

                if !viewModel.tasks.isEmpty {
                    Picker("Filter", selection: $viewModel.filter) {
                        ForEach(TaskFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                if viewModel.tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks Yet",
                        systemImage: "checklist",
                        description: Text("Tap \"Add Task\" to create your first task.")
                    )
                } else if viewModel.displayedTasks.isEmpty {
                    ContentUnavailableView(
                        "No Matching Tasks",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("No tasks match the \"\(viewModel.filter.rawValue)\" filter.")
                    )
                } else {
                    List {
                        ForEach(viewModel.displayedTasks) { task in
                            Button {
                                viewModel.toggleCompletion(for: task.id)
                            } label: {
                                Label {
                                    Text(task.title)
                                        .strikethrough(task.isCompleted)
                                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                } icon: {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(task.isCompleted ? .green : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingTask = task
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: viewModel.deleteTask)
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Task") {
                        isAddingTask = true
                        isTitleFieldFocused = true
                    }
                }
            }
            .sheet(item: $editingTask) { task in
                EditTaskSheet(task: task, viewModel: viewModel) {
                    editingTask = nil
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.hasPendingDeletion {
                    undoBanner
                }
            }
        }
    }

    private var undoBanner: some View {
        let count = viewModel.pendingDeletionTaskIDs.count
        return HStack {
            Text(count == 1 ? "Task deleted" : "\(count) tasks deleted")
            Spacer()
            Button("Undo") {
                viewModel.undoDelete()
            }
            .fontWeight(.semibold)
        }
        .padding()
        .background(.thinMaterial)
    }

    private var addTaskRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField("Task title", text: $newTaskTitle)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTitleFieldFocused)
                    .onSubmit(confirmNewTask)
                    .onChange(of: newTaskTitle) {
                        newTaskTitle = TaskListViewModel.cappedTitle(newTaskTitle)
                    }

                Button("Confirm", action: confirmNewTask)
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Cancel", role: .cancel) {
                    cancelNewTask()
                }
            }

            if let validationMessage = viewModel.validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    private func confirmNewTask() {
        guard viewModel.addTask(title: newTaskTitle) else { return }
        newTaskTitle = ""
        isAddingTask = false
        isTitleFieldFocused = false
    }

    private func cancelNewTask() {
        newTaskTitle = ""
        viewModel.validationMessage = nil
        isAddingTask = false
        isTitleFieldFocused = false
    }
}

private struct EditTaskSheet: View {
    let task: TaskItem
    let viewModel: TaskListViewModel
    let onDismiss: () -> Void

    @State private var title: String
    @FocusState private var isTitleFieldFocused: Bool

    init(task: TaskItem, viewModel: TaskListViewModel, onDismiss: @escaping () -> Void) {
        self.task = task
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        _title = State(initialValue: task.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task title", text: $title)
                        .focused($isTitleFieldFocused)
                        .onChange(of: title) {
                            title = TaskListViewModel.cappedTitle(title)
                        }

                    if let validationMessage = viewModel.validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.validationMessage = nil
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard viewModel.updateTitle(for: task.id, to: title) else { return }
                        onDismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { isTitleFieldFocused = true }
        }
    }
}

#Preview {
    ContentView()
}
