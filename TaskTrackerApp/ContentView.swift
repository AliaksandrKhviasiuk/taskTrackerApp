//
//  ContentView.swift
//  TaskTrackerApp
//
//  Created by Aliaksandr Khviasiuk on 09/08/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = TaskListViewModel()
    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @FocusState private var isTitleFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isAddingTask {
                    addTaskRow
                }

                if viewModel.tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks Yet",
                        systemImage: "checklist",
                        description: Text("Tap \"Add Task\" to create your first task.")
                    )
                } else {
                    List {
                        ForEach(viewModel.tasks) { task in
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
        }
    }

    private var addTaskRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField("Task title", text: $newTaskTitle)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTitleFieldFocused)
                    .onSubmit(confirmNewTask)
                    .onChange(of: newTaskTitle) {
                        if newTaskTitle.count > TaskListViewModel.titleCharacterLimit {
                            newTaskTitle = String(newTaskTitle.prefix(TaskListViewModel.titleCharacterLimit))
                        }
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

#Preview {
    ContentView()
}
