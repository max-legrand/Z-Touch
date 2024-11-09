import { createSignal, onMount, For, Show } from 'solid-js';
import './App.css';
import Card from './Card';
import Modal from './Modal';
import { Project, SortOption, SortDirection, Tag } from './types';

declare global {
    type updateIdxArgs = { to: number, from: number };

    interface Window {
        /** Triggers the button click event on the webview.
        * 
        * @returns void
        */
        buttonClicked: () => void;

        /** Log a message to the console. Since `console.log` is not supported in webview on all platforms, this is the only way to send a log.
        * 
        * @param msg The message to log.
        * @returns void
        */
        zlog: (msg: string) => void;

        /** Triggers the close event on the webview.
        * 
        * @returns void
        */
        triggerClose: () => void;

        /** Gets a list of files in the current project.
        * 
        * @returns A promise that resolves to an array of file paths.
        */
        getFiles: () => Promise<string[]>;

        /** Opens a file dialog to select a file.
        * 
        * @returns A promise that resolves to the selected file path.
        */
        openFileDialog: () => Promise<string>;

        /** Quits the application.
        * 
        * @returns void
        */
        quit: () => void;

        /** Opens a link in the default browser.
        * 
        * @param link The link to open.
        * @returns void
        */
        openLink: (link: string) => void;

        /** Opens a folder in the file explorer.
        * 
        * @param path The path to open.
        * @returns void
        */
        openFolder: (path: string) => void;

        /** Gets a list of projects.
        * 
        * @returns A promise that resolves to an array of projects.
        */
        getProjects: () => Promise<Project[]>;

        /** Adds a new project to the list of projects.
        * 
        * @param project_path The path to the project.
        * @returns void
        */
        addProject: (project_path: string) => void;

        /** Adds a new project to the list of projects using a link in favor of a path.
        * 
        * @param project_link The link to the project.
        * @returns void
        */
        addProjectViaLink: (project_link: string) => void;

        /** Updates the index of a project in the list of projects.
        * 
        * @param args The index and path of the project to update.
        * @returns void
        */
        updateIdx: (args: updateIdxArgs) => void;

        /** Minimizes the window.
        * 
        * @returns void
        */
        minimize: () => void;

        /** Updates a project in the list of projects.
        * 
        * @param project The project to update.
        * @returns void
        */
        updateProject: (project: Project) => void;

        /** Gets a list of tags.
        * 
        * @returns A promise that resolves to an array of tags.
        */
        getTags: () => Promise<Tag[]>;
    }
}

const App = () => {
    const [tags, setTags] = createSignal<Tag[]>([]);
    const [folder, setFolder] = createSignal<string>("");
    const [projects, setProjects] = createSignal<Project[] | null>(null);
    const [loading, setLoading] = createSignal(true);
    const [sortBy, setSortBy] = createSignal<SortOption>('order');
    const [sortDirection, setSortDirection] = createSignal<SortDirection>('asc');
    const [draggedProject, setDraggedProject] = createSignal<Project | null>(null);
    const [dropTarget, setDropTarget] = createSignal<number | null>(null);
    const [searchTerm, setSearchTerm] = createSignal("");
    const [projectLink, setProjectLink] = createSignal("");
    const [modalProject, setModalProject] = createSignal<Project | null>(null);

    async function selectFolder() {
        try {
            window.openFileDialog().then((file) => {
                window.zlog("Selected file: " + file);
                setFolder(file);
            });
        } catch (error: any) {
            window.zlog(`Error selecting folder: ${error.toString()}`);
        }
    }

    function addKeyboardShortcuts() {
        window.addEventListener('keydown', (event) => {

            // Close or quit
            if (event.metaKey && event.key === 'w') {
                event.preventDefault();
                window.zlog("Cmd+W pressed, closing window");
                window.triggerClose();
            } else if (event.ctrlKey && event.key === 'w') {
                event.preventDefault();
                window.zlog("Ctrl+W pressed, closing window");
                window.triggerClose();
            } else if (event.metaKey && event.key === 'q') {
                event.preventDefault();
                window.zlog("Cmd+Q pressed, quitting");
                window.quit();
            } else if (event.ctrlKey && event.key === 'Q') {
                window.zlog("Ctrl+Shift+Q pressed, quitting");
                window.quit();
            }

            // Cmd+R and Ctrl+R to reload the page
            if (event.metaKey && event.key === 'r') {
                event.preventDefault();
                location.reload();
            } else if (event.ctrlKey && event.key === 'r') {
                event.preventDefault();
                location.reload();
            }

            // minimize window
            if ((event.metaKey && event.key === 'm') || (event.ctrlKey && event.key === 'm')) {
                event.preventDefault();
                window.minimize();
            }
        });
    }

    onMount(async () => {
        addKeyboardShortcuts();
        setLoading(true);
        try {
            const fetchedProjects = await window.getProjects();
            setProjects(fetchedProjects);
            window.zlog(`Projects: ${JSON.stringify(fetchedProjects)}`);

            const fetchedTags = await window.getTags();
            setTags(fetchedTags);
            window.zlog(`Tags: ${JSON.stringify(fetchedTags)}`);

        } catch (error) {
            window.zlog(`Error fetching projects: ${error}`);
        } finally {
            setLoading(false);
        }
    });

    function addProjectViaLink() {
        const link = projectLink();
        window.zlog(`Adding project: ${link}`);
        try {
            window.addProjectViaLink(link);
            window.getProjects().then((fetchedProjects) => {
                setProjects(fetchedProjects);
                window.zlog(`Projects: ${JSON.stringify(fetchedProjects)}`);
                setProjectLink("");
            });
        } catch (error) {
            // @ts-ignore - Error will be converted to string
            window.zlog(`Error adding project: ${error.toString()}`);
        }

    }

    function addProject() {
        const selected = folder();
        window.zlog(`Adding project: ${selected}`);
        try {
            window.addProject(selected);
            window.getProjects().then((fetchedProjects) => {
                setProjects(fetchedProjects);
                window.zlog(`Projects: ${JSON.stringify(fetchedProjects)}`);
                setFolder("");
            });
        } catch (error) {
            // @ts-ignore - Error will be converted to string
            window.zlog(`Error adding project: ${error.toString()}`);
        }
    }

    const toggleSort = (option: SortOption) => {
        if (sortBy() === option) {
            setSortDirection(prev => prev === 'asc' ? 'desc' : 'asc');
        } else {
            setSortBy(option);
            setSortDirection('asc');
        }
    };

    const filteredProjects = () => {
        if (!projects()) return [];
        const term = searchTerm().toLowerCase();
        return projects()!.filter(project =>
            project.name.toLowerCase().includes(term) ||
            project.tags.some(tag => tag.name.toLowerCase().includes(term))
        );
    };

    const sortedProjects = () => {
        return [...filteredProjects()].sort((a, b) => {
            if (sortBy() === 'name') {
                return sortDirection() === 'asc'
                    ? a.name.localeCompare(b.name)
                    : b.name.localeCompare(a.name);
            } else {
                return sortDirection() === 'asc'
                    ? a.order_idx - b.order_idx
                    : b.order_idx - a.order_idx;
            }
        });
    };

    const openProject = (project: Project) => {
        if (project.path) {
            window.openFolder(project.path);
        } else {
            window.openLink(project.url!);
        }
    };

    const openProjectModal = (project: Project) => {
        setModalProject(project);
    };

    const closeProjectModal = () => {
        setModalProject(null);
    };

    const saveProjectChanges = async (updatedProject: Project) => {
        setProjects(prev =>
            prev ? prev.map(p => p.id === updatedProject.id ? updatedProject : p) : null
        );

        closeProjectModal();
        window.updateProject(updatedProject);
        try {
            setTags(await window.getTags());
        }
        catch (error) {
            window.zlog(`Error updating tags: ${error}`);
        }
    };

    const handleDragStart = (project: Project) => {
        setDraggedProject(project);
        document.body.classList.add('dragging');
    };

    const handleDragEnd = () => {
        setDraggedProject(null);
        setDropTarget(null);
        document.body.classList.remove('dragging');
    };

    const handleDragOver = (event: DragEvent, targetProject: Project) => {
        event.preventDefault();
        if (event.dataTransfer) {
            event.dataTransfer.dropEffect = 'move';
        }
        setDropTarget(targetProject.id);
    };

    const handleDragLeave = () => {
        setDropTarget(null);
    };

    const handleDrop = (event: DragEvent, targetProject: Project) => {
        event.preventDefault();
        const draggedProj = draggedProject();
        if (!draggedProj || draggedProj.id === targetProject.id) return;
        // Update the order of the projects
        window.updateIdx({ to: targetProject.order_idx, from: draggedProj.order_idx });
        if (draggedProj && draggedProj.id !== targetProject.id) {
            const updatedProjects = sortedProjects().map(p => {
                if (p.id === draggedProj.id) {
                    return { ...p, order_idx: targetProject.order_idx };
                }
                if (p.id === targetProject.id) {
                    return { ...p, order_idx: draggedProj.order_idx };
                }
                return p;
            });
            setProjects(updatedProjects);
            window.zlog(`Reordered projects: ${JSON.stringify(updatedProjects)}`);
        }
        setDraggedProject(null);
        setDropTarget(null);
    };

    const handleSearchKeyDown = (e: KeyboardEvent, addEnter = false) => {
        // If ctrl+a or cmd+a is entered, select all text
        if ((e.ctrlKey || e.metaKey) && e.key === 'a') {
            e.preventDefault();
            (e.target as HTMLInputElement | HTMLTextAreaElement).select();
        }

        if (addEnter) {
            if (e.key === 'Enter') {
                e.preventDefault();
                addProjectViaLink();
            }
        }
    }

    return (
        <Show when={!loading()} fallback={<div class="loading"></div>}>
            <div class="content">
                <h1 class="text-stone-200">Z-touch</h1>

                <Show when={folder() !== ""}>
                    <p>Selected folder: {folder()}</p>
                    <br />
                    <div class="flex justify-center w-full">
                        <button type="button" class="w-1/4" onClick={addProject}>Add Project</button>
                    </div>
                </Show>
                <div class="flex justify-center w-full">
                    <button
                        class="my-0 w-1/4"
                        onClick={selectFolder}>Select Folder</button>
                </div>
                <div class="flex justify-center w-full">
                    <input
                        type="text"
                        class="
                        border
                        text-sm
                        rounded-lg
                        block
                        w-1/3
                        p-2.5
                        bg-zinc-900
                        border-zinc-400
                        placeholder-gray-400
                        text-white
                        focus:ring-blue-500
                        focus:border-blue-500
                        mr-2
                    "
                        placeholder="Add Project via link..."
                        value={projectLink()}
                        onKeyDown={(e) => { handleSearchKeyDown(e, true) }}
                        onInput={(e) => setProjectLink((e.target as HTMLInputElement).value)}
                    />
                    <button
                        class="my-0 w-1/6"
                        onClick={addProjectViaLink}>Add</button>
                </div>


                <div class="sort-controls my-0">
                    <button onClick={() => toggleSort('name')} class={sortBy() === 'name' ? 'active' : ''}>
                        Sort by Name {sortBy() === 'name' && (sortDirection() === 'asc' ? '↑' : '↓')}
                    </button>
                    <button onClick={() => toggleSort('order')} class={sortBy() === 'order' ? 'active' : ''}>
                        Sort by Order {sortBy() === 'order' && (sortDirection() === 'asc' ? '↑' : '↓')}
                    </button>
                </div>
                <input
                    type="text"
                    class="
                        border
                        text-sm
                        rounded-lg
                        block
                        w-1/3
                        p-2.5
                        bg-zinc-900
                        border-zinc-400
                        placeholder-gray-400
                        text-white
                        focus:ring-blue-500
                        focus:border-blue-500
                        mb-2
                    "
                    placeholder="Search projects or tags..."
                    value={searchTerm()}
                    onKeyDown={handleSearchKeyDown}
                    onInput={(e) => setSearchTerm((e.target as HTMLInputElement).value)}
                />
                <Show when={projects() !== null && projects()!.length > 0} fallback={<p>No projects available</p>}>
                    <div class="project-grid">
                        <For each={sortedProjects()}>
                            {(project) => (
                                <Card
                                    project={project}
                                    isDropTarget={dropTarget() === project.id}
                                    onDragStart={handleDragStart}
                                    onDragEnd={handleDragEnd}
                                    onDragOver={handleDragOver}
                                    onDragLeave={handleDragLeave}
                                    onDrop={handleDrop}
                                    onClick={openProjectModal}
                                    onOpenProject={openProject}
                                />
                            )}
                        </For>
                    </div>
                </Show>

            </div>
            <Show when={modalProject() !== null}>
                <Modal
                    tags={tags()}
                    project={modalProject()!}
                    onClose={closeProjectModal}
                    onSave={saveProjectChanges}
                />
            </Show>
        </Show>
    );
};

export default App;
