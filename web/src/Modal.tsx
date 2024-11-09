import { createSignal, onCleanup, onMount, For, Show } from 'solid-js';
import { Project, Tag, getContrastTextColor } from './types';
import "./Modal.css";

type ModalProps = {
    project: Project;
    tags: Tag[];
    onClose: () => void;
    onSave: (updatedProject: Project) => void;
};


const Modal = (props: ModalProps) => {
    const [editedProject, setEditedProject] = createSignal<Project>({ ...props.project });
    const [selectedColor, setSelectedColor] = createSignal("#000000");
    const [tagInput, setTagInput] = createSignal("");
    const [showAutocomplete, setShowAutocomplete] = createSignal(false);
    const [selectedIndex, setSelectedIndex] = createSignal(-1);

    // ID for new tags. Defaults to -1, this will get set when the component mounts.
    let newId = -1;

    // Filter existing tags based on input
    const filteredTags = () => {
        const input = tagInput().toLowerCase();

        // Get current project tag IDs
        const projectTagIds = new Set(editedProject().tags.map(t => t.id));

        // If input is empty and dropdown should be shown, return all unused tags
        if (!input && showAutocomplete()) {
            return props.tags.filter(tag => !projectTagIds.has(tag.id));
        }

        // If input exists, filter by name
        return props.tags.filter(tag =>
            tag.name.toLowerCase().includes(input) &&
            !projectTagIds.has(tag.id)
        );
    };

    const handleTagKeyDown = (e: KeyboardEvent) => {
        if ((e.ctrlKey || e.metaKey) && e.key === 'a') {
            e.preventDefault();
            (e.target as HTMLInputElement).select();
            return;
        }

        // Handle arrow down with empty input
        if (e.key === 'ArrowDown') {
            e.preventDefault();
            // Always show dropdown on arrow down, regardless of current state
            setShowAutocomplete(true);
            const filtered = filteredTags();
            setSelectedIndex(prev =>
                prev === -1 ? 0 : Math.min(prev + 1, filtered.length - 1)
            );
            return;
        }

        const filtered = filteredTags();

        if (e.key === 'ArrowUp') {
            e.preventDefault();
            setSelectedIndex(prev => Math.max(prev - 1, -1));
        }

        if (e.key === 'Enter') {
            e.preventDefault();
            const selectedTag = filtered[selectedIndex()];

            if (selectedTag) {
                addTag(selectedTag);
            } else if (tagInput().trim()) {
                // Create new tag if no suggestion selected
                const color = selectedColor();
                const [r, g, b] = color.slice(1).match(/.{2}/g)!.map(x => parseInt(x, 16));
                const tag = {

                    id: newId,
                    name: tagInput().trim(),
                    color: { r, g, b }
                };
                addTag(tag);
                props.tags.push(tag);

                if (newId == props.tags.length) {
                    newId += 1;
                } else {
                    for (let i = 1; i <= props.tags.length; i++) {
                        if (props.tags[i - 1].id !== i) {
                            newId = i; break;
                        }
                    }
                }
            }
        }
    };

    const handleTagInput = (e: Event) => {
        const input = (e.target as HTMLInputElement).value;
        setTagInput(input);
        // Always show dropdown if we have available tags to show
        const hasAvailableTags = props.tags.length > editedProject().tags.length;
        setShowAutocomplete(hasAvailableTags);
        setSelectedIndex(-1);
    };

    onMount(() => {
        newId = props.tags.length + 1;
        for (let i = 1; i <= props.tags.length; i++) {
            if (props.tags[i - 1].id !== i) {
                newId = i;
            }
            break;
        }
        const handleKeyDown = (event: KeyboardEvent) => {
            if (event.key === 'Escape') {
                if (showAutocomplete()) {
                    setShowAutocomplete(false);
                    setSelectedIndex(-1);
                } else {
                    // Save on ESC instead of closing.
                    // TODO: see if this behavior should change -- maybe we just close on ESC insted of saving
                    props.onSave(editedProject());
                }
            }
        };

        window.addEventListener('keydown', handleKeyDown);
        onCleanup(() => window.removeEventListener('keydown', handleKeyDown));
    });

    const handleInputChange = (e: Event, field: string) => {
        const target = e.target as HTMLInputElement;
        setEditedProject(prev => ({ ...prev, [field]: target.value }));
    };

    const handleInput = (e: KeyboardEvent) => {
        if ((e.ctrlKey || e.metaKey) && e.key === 'a') {
            e.preventDefault();
            (e.target as HTMLInputElement | HTMLTextAreaElement).select();
        }

        if (e.key === 'Enter') {
            e.preventDefault();
            props.onSave(editedProject());
        }
    };

    const addTag = (tag: Tag) => {
        setEditedProject(project => ({
            ...project,
            tags: [...project.tags, tag]
        }));
        setTagInput("");
        setShowAutocomplete(false);
        setSelectedIndex(-1);
    };

    const removeTag = (tagId: number) => {
        setEditedProject(project => ({
            ...project,
            tags: project.tags.filter(t => t.id !== tagId)
        }));

        // Set the newId to the ID we just removed
        newId = tagId;
    };

    // Click outside to close autocomplete
    const handleClickOutside = (e: MouseEvent) => {
        const target = e.target as HTMLElement;
        if (!target.closest('.tag-input-container')) {
            setShowAutocomplete(false);
            setSelectedIndex(-1);
        }
    };

    onMount(() => {
        document.addEventListener('click', handleClickOutside);
        onCleanup(() => document.removeEventListener('click', handleClickOutside));
    });

    onCleanup(() => {
        setShowAutocomplete(false);
        setSelectedIndex(-1);
        setTagInput("");
    });

    return (
        <div class="modal-overlay">
            <div class="modal-content">
                <h2 class="modal-title">Edit Project</h2>
                <input
                    type="text"
                    value={editedProject().name}
                    onInput={(e) => handleInputChange(e, 'name')}
                    onKeyDown={handleInput}
                    class="modal-input"
                />
                <input
                    type="text"
                    disabled={true}
                    class="modal-input"
                    value={editedProject().path || editedProject().url || ''}
                />
                <textarea
                    value={editedProject().description || ''}
                    onInput={(e) => handleInputChange(e, 'description')}
                    onKeyDown={handleInput}
                    class="modal-textarea"
                    placeholder="Project description"
                />

                <div class="modal-tags">
                    <div class="tag-input-container relative">
                        <div class="tag-input-wrapper">
                            <input
                                value={tagInput()}
                                onInput={handleTagInput}
                                onKeyDown={handleTagKeyDown}
                                type="text"
                                placeholder="＋ Add Tag"
                                class="add-tag-button"
                            />
                            <div class="color-preview" style={`background-color: ${selectedColor()}`}></div>
                            <input
                                type="color"
                                value={selectedColor()}
                                onInput={(e) => setSelectedColor(e.target.value)}
                                class="color-picker"
                            />
                        </div>

                        <Show when={showAutocomplete() && filteredTags().length > 0}>
                            <div class="autocomplete-dropdown">
                                <For each={filteredTags()}>
                                    {(tag, index) => (
                                        <div
                                            class={`autocomplete-item ${index() === selectedIndex() ? 'selected' : ''}`}
                                            onClick={() => addTag(tag)}
                                        >
                                            <div
                                                class="tag-preview"
                                                style={`background-color: rgb(${tag.color.r}, ${tag.color.g}, ${tag.color.b})`}
                                            ></div>
                                            <span class="tag-name">{tag.name}</span>
                                        </div>
                                    )}
                                </For>
                            </div>
                        </Show>
                    </div>

                    <Show when={editedProject().tags.length > 0}>
                        <p>Tags:</p>
                    </Show>
                    <For each={editedProject().tags}>
                        {(tag) => {
                            const textColor = getContrastTextColor(tag.color.r, tag.color.g, tag.color.b);
                            return (
                                <span class="tag-pill"
                                    id={tag.id.toString()}
                                    style={`
                                        background-color: rgb(${tag.color.r}, ${tag.color.g}, ${tag.color.b});
                                        color: ${textColor}
                                    `}
                                >
                                    {tag.name}
                                    <span
                                        style={`
                                            cursor: pointer;
                                            margin-left: 10px;
                                            font-size: 10px !important;
                                        `}
                                        onClick={() => removeTag(tag.id)}
                                    >❌</span>
                                </span>
                            );
                        }}
                    </For>
                </div>

                <div class="modal-actions">
                    <button onClick={() => props.onSave(editedProject())} class="modal-button save-button">Save</button>
                    <button onClick={props.onClose} class="modal-button cancel-button">Cancel</button>
                </div>
            </div>
        </div>
    );
};

export default Modal;
