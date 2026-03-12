# Create area-depth slices for the lake.inc file of the PRYSM Environment submodel
# From polygons in a KML file
# RGT 20240724

# Install necessary packages
install.packages(c("sf", "xml2", "dplyr", "ggplot2", "scico"))

# Load packages
library(sf)
library(xml2)
library(dplyr)
library(ggplot2)
library(scico)

# Set working directory
setwd("/Users/rebec/Downloads/")

# Load the KML file
kml_file <- "BearLake_contours_updated.kml"
kml_data <- read_xml(kml_file)

# Check namespaces (there's multiple places where the data could be in the KML;
# it was located in the kml namespace for my file. Other likely place is d1.)
namespaces <- xml_ns(kml_data)
print(namespaces)

# Choose the kml namespace
ns <- c(kml = "http://www.opengis.net/kml/2.2")

# Find all Placemark nodes using the namespace
placemarks <- xml_find_all(kml_data, ".//kml:Placemark", ns)
print(placemarks)

# Extract coordinates and depth data
contour_polygons <- list()
depths <- numeric()
for (placemark in placemarks) {
  # Extract coordinates
  coordinates <- xml_find_all(placemark, ".//kml:coordinates", ns)
  coords_text <- xml_text(coordinates)
  
  coords_text <- trimws(coords_text) #Trim leading and tailing white spaces
  
  # Split the coordinates text by space and then by commas
  coords_list <- strsplit(coords_text, "\\s+")[[1]]
  coords_matrix <- do.call(rbind, lapply(coords_list, function(x) {
    coords <- as.numeric(strsplit(x, ",")[[1]])
    c(coords[1], coords[2])  # Only take the first two values (longitude, latitude)
  }))
  
  # Print the final coordinates and check they look okay
  print(coords_matrix)
  
  # Create a POLYGON string
  coords_str <- paste0("POLYGON ((", paste(apply(coords_matrix, 1, paste, collapse = " "), collapse = ", "), "))")
  
  coords_str <- na.omit(coords_str)
  
  # Convert to spatial object
  coords <- st_as_sfc(coords_str, crs = 4326)
  
  # Make sure it's 2D - that's all we need
  coords <- st_zm(coords, drop = TRUE, what = "ZM")
  
  # Extract depth from the feature name
  depth_text <- xml_text(xml_find_first(placemark, ".//kml:name", ns))
  depth <- as.numeric(gsub("m", "", unlist(strsplit(depth_text, " "))[2]))
  
  contour_polygons <- c(contour_polygons, coords)
  depths <- c(depths, depth)
}

# Create a data frame with the contour polygons and depths
contour_df <- data.frame(depth = depths)
contour_df$geometry <- st_sfc(contour_polygons, crs = 4326)
contour_sf <- st_as_sf(contour_df)

# Check for invalid geometries
invalid_geometries <- st_is_valid(contour_sf, reason = TRUE)
print(invalid_geometries)

# Correct any invalid geometries
for (i in seq_along(contour_sf$geometry)) {
  if (!st_is_valid(contour_sf$geometry[i])) {
    print(paste("Fixing invalid polygon:", i))
    print(st_is_valid(contour_sf$geometry[i], reason = TRUE))
    
    # Aggressively simplify and buffer the invalid polygons to attempt to fix them
    fixed_geometry <- tryCatch({
      st_buffer(st_simplify(contour_sf$geometry[i], dTolerance = 0.1), 0)
    }, error = function(e) {
      print(paste("Error fixing polygon:", i))
      print(e)
      return(NULL)
    })
    
    # If fixing fails, skip this polygon
    if (is.null(fixed_geometry) || !st_is_valid(fixed_geometry)) {
      print(paste("Skipping invalid polygon:", i))
      next
    }
    
    contour_sf$geometry[i] <- fixed_geometry
  }
}

# Ensure all geometries are now valid
contour_sf <- st_make_valid(contour_sf)
invalid_geometries <- st_is_valid(contour_sf, reason = TRUE)
print(invalid_geometries)

# Calculate the area of each depth slice in hectares (1 hectare = 10,000 square meters)
contour_sf <- contour_sf %>%
  mutate(area_ha = st_area(geometry) / 10000)

# Print out the areas - yay! These will go in the "data area" part of the lake.inc file
print(contour_sf)


## Create a simple bathymetric map using the contour polygons ##
# But missing 1-2m line! Get that from Google Earth

# Make sure the contours are arranged by depth (otherwise the largest area will cover up the rest)
contour_sf <- contour_sf %>% arrange(depth)


# Plot the bathymetric map, filling in each contour with a unique color
ggplot() +
  geom_sf(data = contour_sf, aes(color = as.factor(depth), fill = as.factor(depth))) +
  scale_fill_viridis_d(option = "viridis") +
  scale_color_viridis_d(option = "viridis") +
  coord_sf() +
  theme_minimal() +
  labs(title = "Bear Lake", fill = "Depth (m)", color = "Depth (m)", x = "Longitude", y = "Latitude")


glasgow_palette <- rev(scico(16, palette = "glasgow"))

# Use batlow
ggplot() +
  geom_sf(data = contour_sf, color = 'black', fill = NA, linewidth = 1.5) +
  
  geom_sf(data = contour_sf, aes(color = as.factor(depth), fill = as.factor(depth))) +
  scale_fill_manual(values = glasgow_palette) +
  scale_color_manual(values = glasgow_palette) +
  coord_sf() +
  theme_minimal() +
  #labs(title = "Bear Lake", fill = "Depth (m)", color = "Depth (m)", x = "Longitude", y = "Latitude") + 
  theme_minimal() +
  theme(
    panel.background = element_blank(),
    plot.background = element_blank(),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank()
  )

ggsave("/Users/rebec/Downloads/BearLakewoutline.png", dpi = 600, bg = "transparent", width = 6, height = 4, units = "in")




# Plot the bathymetric map, with only the contours as lines
ggplot() +
  geom_sf(data = contour_sf, aes(color = as.factor(depth)), fill = NA, linewidth = 1) +
  scale_color_viridis_d(option = "viridis") +
  coord_sf() +
  theme_minimal() +
  labs(title = "Bear Lake", color = "Depth (m)", x = "Longitude", y = "Latitude", fill = "")
#scale_color

# Extract only the area values (in hectares)
area_values <- sprintf("%.3f", contour_sf$area_ha)

# Format them for the lake.inc file
cat(paste(area_values, collapse = ", "))





# Legend alone 

library(ggplot2)
library(scico)
library(cowplot)

# Create dummy data
df <- data.frame(x = 1, y = seq(0, 18, length.out = 100), z = seq(0, 18, length.out = 100))

# Plot vertical gradient
p <- ggplot(df, aes(x = x, y = y, fill = z)) +
  geom_tile() +
  scale_fill_scico(palette = "glasgow", limits = c(0, 18)) +
  theme_void() +
  theme(legend.position = "right") +
  labs(fill = "Depth (m)")

# Show just the colorbar
legend <- get_legend(p)

# Plot the colorbar alone
plot_grid(legend)


# Load scico and create color palette
# Load palette
library(scico)
glasgow_palette <- scico(19, palette = "glasgow")  # 0 to 18 = 19 colors

# Create dummy matrix with 19 rows and 1 column
z <- matrix(1:19, nrow = 19, ncol = 1)

# Set up PNG device if saving:
# png("glasgow_colorbar.png", width = 4, height = 6, units = "in", res = 300, bg = "transparent")

# Plot vertical color bar
image(x = 1, y = 0:18, z = t(z), col = glasgow_palette,
      axes = FALSE, xlab = "", ylab = "")

# Add axis and box
axis(2, at = seq(0, 18, by = 2), las = 1)
box()
title("Depth (m)", line = 2.5)

# Close device if saving:
# dev.off()

