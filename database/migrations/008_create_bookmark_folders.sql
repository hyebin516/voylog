CREATE TABLE bookmark_folders (
    folder_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users (user_id),
    name       VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_bookmark_folders_user_id ON bookmark_folders (user_id);

-- A bookmark can belong to multiple folders and a folder can hold multiple
-- bookmarks (tag-style, not a strict one-folder-per-bookmark hierarchy).
CREATE TABLE bookmark_folder_items (
    folder_id   UUID NOT NULL REFERENCES bookmark_folders (folder_id),
    bookmark_id UUID NOT NULL REFERENCES bookmarks (bookmark_id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (folder_id, bookmark_id)
);

CREATE INDEX idx_bookmark_folder_items_bookmark_id ON bookmark_folder_items (bookmark_id);
