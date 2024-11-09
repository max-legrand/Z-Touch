import { createSignal, For } from 'solid-js';
import { getContrastTextColor, Project } from './types';

type CardProps = {
    project: Project,
    isDropTarget: boolean,
    onDragStart: (project: Project) => void,
    onDragEnd: () => void,
    onDragOver: (event: DragEvent, project: Project) => void,
    onDragLeave: () => void,
    onDrop: (event: DragEvent, project: Project) => void
    onClick: (project: Project) => void
    onOpenProject: (project: Project) => void
};

const Card = (props: CardProps) => {
    const [isDragging, setIsDragging] = createSignal(false);
    let isDragStarted = false;

    const handleClick = (event: MouseEvent) => {
        if (!isDragStarted && !(event.target as HTMLElement).closest('.project-name')) {
            props.onClick(props.project);
        }
    };

    const handleDragStart = (event: DragEvent) => {
        isDragStarted = true;
        setIsDragging(true);
        if (event.dataTransfer && event.target instanceof HTMLElement) {
            event.dataTransfer.effectAllowed = 'move';
            event.dataTransfer.setData('text/plain', props.project.id.toString());

            const cardElement = event.currentTarget as HTMLElement;
            const rect = cardElement.getBoundingClientRect();

            // Create a drag ghost that matches the card size and style
            const dragGhost = document.createElement('div');
            dragGhost.className = 'drag-ghost';
            dragGhost.style.width = `${rect.width}px`;
            dragGhost.style.height = `${rect.height}px`;
            dragGhost.style.border = '2px solid white';
            dragGhost.style.borderRadius = '8px';
            dragGhost.style.padding = '1rem';
            dragGhost.style.boxSizing = 'border-box';
            dragGhost.style.backgroundColor = 'rgba(42, 42, 42, 0.9)';
            dragGhost.style.boxShadow = '0 10px 20px rgba(0, 0, 0, 0.4)';

            const content = document.createElement('div');
            content.className = 'drag-ghost-content';
            content.innerHTML = `
                <p class="project-name">${props.project.name}</p>
                <br/>
            `;
            dragGhost.appendChild(content);

            document.body.appendChild(dragGhost);
            event.dataTransfer.setDragImage(dragGhost, rect.width / 2, rect.height / 2);

            // Remove the ghost after a short delay
            setTimeout(() => {
                document.body.removeChild(dragGhost);
            }, 0);
        }
        props.onDragStart(props.project);
    };

    const handleDragEnd = () => {
        setIsDragging(false);
        props.onDragEnd();
        setTimeout(() => {
            isDragStarted = false;
        }, 0);
    };

    return (
        <div
            class={`card ${isDragging() ? 'dragging' : ''}`}
            draggable="true"
            onDragStart={handleDragStart}
            onDragEnd={handleDragEnd}
            onDragOver={(e) => props.onDragOver(e, props.project)}
            onDragLeave={props.onDragLeave}
            onDrop={(e) => props.onDrop(e, props.project)}
            onClick={handleClick}
        >
            <div class="card-content">
                <a
                    href="#"
                    class="
                        hover:underline
                        project-name
                        cursor-alias
                        my-2
                    "
                    onClick={(e) => {
                        e.preventDefault();
                        props.onOpenProject(props.project);
                    }}
                >
                    {props.project.name}
                </a>
                <div class="
                    tags-container
                    my-1
                ">
                    <For each={props.project.tags}>
                        {(tag) => {
                            const textColor = getContrastTextColor(tag.color.r, tag.color.g, tag.color.b);
                            return (
                                <span
                                    class="tag"
                                    style={`
                                        color: ${textColor};
                                        background-color: rgb(${tag.color.r}, ${tag.color.g}, ${tag.color.b})
                                    `}
                                >
                                    {tag.name}
                                </span>
                            )
                        }}
                    </For>
                </div>
            </div>
            {props.isDropTarget && <div class="drop-indicator"></div>}
        </div>
    );
};

export default Card;
