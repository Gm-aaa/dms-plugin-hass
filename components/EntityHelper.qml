pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import "../services"

QtObject {
    id: root

    /**
     * Get the effective value for an entity attribute, considering optimistic UI updates.
     * @param entityData - The entity data object
     * @param attr - The attribute name to retrieve
     * @param defaultValue - The default value if attribute is not found
     * @returns The effective value (optimistic or real)
     */
    function getEffectiveValue(entityData, attr, defaultValue) {
        if (!entityData) return defaultValue;

        // Special case for "state" - use entity.state directly
        if (attr === "state") {
            return HomeAssistantService.getEffectiveValue(
                entityData.entityId,
                "state",
                entityData.state || defaultValue
            );
        }

        const realValue = (entityData.attributes && entityData.attributes[attr] !== undefined)
            ? entityData.attributes[attr]
            : defaultValue;

        return HomeAssistantService.getEffectiveValue(
            entityData.entityId,
            attr,
            realValue
        );
    }

    /**
     * Get the effective state for an entity, considering optimistic UI updates.
     * @param entityData - The entity data object
     * @returns The effective state
     */
    function getEffectiveState(entityData) {
        if (!entityData) return "";
        return HomeAssistantService.getEffectiveValue(
            entityData.entityId,
            "state",
            entityData.state || ""
        );
    }

    /**
     * Safely retrieve an attribute value from an entity.
     * @param entity - The entity object
     * @param attrName - The attribute name
     * @param defaultValue - The default value if not found
     * @returns The attribute value or default
     */
    function safeAttr(entity, attrName, defaultValue) {
        return (entity && entity.attributes && entity.attributes[attrName] !== undefined)
            ? entity.attributes[attrName]
            : defaultValue;
    }

    /**
     * Check if an entity is in an active state.
     * @param entityData - The entity data object
     * @returns true if the entity is active, false otherwise
     */
    function isActive(entityData) {
        if (!entityData) return false;
        return HassConstants.isActiveState(entityData.domain, getEffectiveState(entityData));
    }

    /**
     * Get the appropriate color for an entity based on its domain and state.
     * @param entityData - The entity data object
     * @param theme - The theme object
     * @returns The color for the entity
     */
    function getStateColor(entityData, theme) {
        if (!entityData) return theme.primary;
        return HassConstants.getStateColor(entityData.domain, getEffectiveState(entityData), theme);
    }

    /**
     * Get the icon for an entity.
     * @param entityData - The entity data object
     * @param customIcons - Optional custom icon overrides
     * @returns The icon name
     */
    function getEntityIcon(entityData, customIcons) {
        if (!entityData) return "sensors";
        const entityId = entityData.entityId || "";
        const domain = entityData.domain || "";
        return (customIcons && customIcons[entityId]) || HassConstants.getIconForDomain(domain);
    }

    function isSwitchable(entityData) {
        if (!entityData) return false;
        const domain = entityData.domain || "";
        return ["switch", "light", "input_boolean", "fan", "automation", "script", "group", "climate"].includes(domain);
    }

    /**
     * Format the entity state value with unit of measurement.
     * @param entityData - The entity data object
     * @returns The formatted state value
     */
    function formatStateValue(entityData) {
        if (!entityData) return "?";
        const state = getEffectiveState(entityData);
        const unit = entityData.unitOfMeasurement || "";
        return HassConstants.formatStateValue(state, unit);
    }

    /**
     * Get the icon background color for an entity.
     * @param entityData - The entity data object
     * @param theme - The theme object
     * @returns The background color
     */
    function getIconBackgroundColor(entityData, theme) {
        if (!entityData) return theme.surfaceVariant;
        return HassConstants.getIconBackgroundColor(
            entityData.domain,
            getEffectiveState(entityData),
            theme
        );
    }

    /**
     * Decide whether a pinned entity should be shown on the bar, per a visibility rule.
     * rule = { op: "always"|"active"|"eq"|"ne"|"gt"|"lt", value: <string|number> }
     * A missing or "always" rule => always visible (backwards compatible).
     * "active" = the state is "meaningful" — not in a set of empty/off-like values
     * (off, idle, none, closed, standby, unavailable, unknown, 0, ""). This suits bar
     * display (e.g. a countdown "12m" shows, "off" hides) and also covers on/open/playing.
     * "gt"/"lt" compare the leading number of the state (e.g. "12m" -> 12);
     * a non-numeric state => hidden.
     * @param entityData - The entity data object
     * @param rule - The visibility rule for this entity (may be undefined)
     * @returns true if the entity should be shown
     */
    readonly property var _inactiveStates: ["", "0", "off", "idle", "none", "closed",
        "standby", "unavailable", "unknown", "false", "not_home", "disconnected", "paused"]

    function entityVisible(entityData, rule) {
        if (!entityData) return false;
        if (!rule || !rule.op || rule.op === "always") return true;

        const state = getEffectiveState(entityData);
        switch (rule.op) {
        case "active":
            return _inactiveStates.indexOf(String(state).trim().toLowerCase()) === -1;
        case "eq":
            return String(state) === String(rule.value);
        case "ne":
            return String(state) !== String(rule.value);
        case "gt":
        case "lt": {
            const n = parseFloat(state);
            const v = parseFloat(rule.value);
            if (isNaN(n) || isNaN(v)) return false;
            return rule.op === "gt" ? (n > v) : (n < v);
        }
        default:
            return true;
        }
    }
}
