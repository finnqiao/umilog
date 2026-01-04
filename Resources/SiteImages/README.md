# Site Images

This folder contains thumbnail images for dive sites displayed in the app.

## Naming Convention

Images should be named using the pattern:
```
site_{siteId}.jpg
```

Where `{siteId}` matches the site's ID in the database.

## Image Requirements

- **Format**: JPEG or PNG
- **Size**: 200x200 pixels minimum (square recommended)
- **Aspect Ratio**: 1:1 (square) preferred, images will be cropped to fit
- **File Size**: Keep under 100KB per image for optimal app size

## Examples

```
site_blue_corner_wall.jpg
site_barracuda_point.jpg
site_turtle_tomb.jpg
```

## Finding Site IDs

Site IDs can be found in the seed data files:
- `Resources/SeedData/sites_extended.json`
- `Resources/SeedData/sites_wikidata.json`

## Fallback Behavior

If no image is found for a site, the app displays a gradient placeholder with an icon based on the site type (reef, wreck, cave, etc.).
