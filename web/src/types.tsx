/** Represents a color in RGB format. */
type Color = {
    r: number,
    g: number,
    b: number,
};

/** Represents a tag with an id, name, and color. */
type Tag = {
    id: number,
    name: string,
    color: Color
};

/** Represents a project with an id, name, path, url, description, tags, and order_idx. */
type Project = {
    id: number
    name: string
    path: string | null
    url: string | null
    description: string
    tags: Tag[]
    order_idx: number
};

type SortOption = 'name' | 'order';
type SortDirection = 'asc' | 'desc';

/** Returns the appropriate text color for a given background color. */
export const getContrastTextColor = (r: number, g: number, b: number) => {
    // Calculate relative luminance using sRGB formula
    const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

    // Use white text for darker backgrounds (luminance < 0.5)
    // Use black text for lighter backgrounds (luminance >= 0.5)
    return luminance < 0.5 ? "white" : "black";
};

export type { Color, Tag, Project, SortOption, SortDirection };

