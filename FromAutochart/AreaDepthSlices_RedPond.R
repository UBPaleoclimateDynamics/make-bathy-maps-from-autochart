####################################################
#### Create area-depth slices using a .kml file ####
####################################################

# Authors: RGT (modified from original code by EKT)

install.packages("raster")
#install.packages("rgdal")
install.packages("RColorBrewer")
install.packages("terra")

#load necessary packages
library(raster)
#library(rgdal)
library(terra)
library(RColorBrewer)

library(scico)


#############################

## Look at kml
redPond_kml <- raster('/Users/rebec/OneDrive/Documents2/RedPond/bwRedPond.kml')
plot(redPond_kml)

## Crop out legend/other info
e <- as(extent(-78.915, -78.9105, 42.13282, 42.134), 'SpatialPolygons')
crs(e) <- "+proj=longlat +datum=WGS84 +no_defs"
lake <- (crop(redPond_kml, e))
plot(lake)

## Set zeros to NAs to get rid of background
lake[lake == 255] <- NA

## Re-scale raster values to depth based on histogram
rescale <- -(lake-255)/12.5

## Plot the bathymetric map
plot(rescale)
contour(rescale, add =T)

## Look at range of values
hist(rescale)

# Create a raster
spatRescale <- as(rescale, 'SpatRaster')

# 1:20 matches the color bar on the .kml file
rcl <- matrix(c(0:20, 1:21, as.factor(0:20)),  ncol = 3)

# Use a color palette from scientific colormaps (Crameri et al)
glasgow_palette <- rev(scico(18, palette = "glasgow"))[3:18] # Get 18 colors

# Apply the adjusted classification
c_bathy <- classify(spatRescale, rcl)

# Make a plot
plot(c_bathy, col = glasgow_palette, main = "Red Pond bathymetry")
# Add black contour lines
#contour(spatRescale, add = TRUE, col = "black", lwd = 0.5, levels = seq(0, 16, by = 1), drawlabels = F)

png("Red_bathymetry.png", width = 6, height = 4, units = "in", res = 600, bg = "transparent")


#############################

# Calculate the mean lake depth
mean_depth <- mean(values(c_bathy), na.rm = TRUE)

# Print the mean depth
print(paste("Mean Lake Depth:", round(mean_depth, 2), "meters"))

############################## Calculate area-depth slices

# Initialize depth_area to be a numeric vector to store the areas
depth_area <- numeric(nrow(rcl))

# Loop through each depth level and calculate the area
for (i in 1:nrow(rcl)) {
  depth_slice <- c_bathy
  
  # Mask values that are deeper than the current depth level
  depth_slice[depth_slice < i] <- NA
  
  # Check what the depth_slice looks like
  plot(depth_slice, main = paste("Depth slice at level", i))
  
  # Calculate the area for the current depth level
  result <- expanse(depth_slice, unit = 'm', transform = TRUE)
  
  # Make sure result is a scalar, sum it if it's not
  if (length(result) > 1) {
    result <- sum(result, na.rm = TRUE)
  }
  
  print(paste("Depth:", i, "Area:", result))
  
  # Assign the result to the depth_area vector
  depth_area[i] <- result
}

# Print final depth_area values
print(round(depth_area / 10000, 3))  # Convert to hectares (ha)

depth_values <- 1:length(depth_area)
all_slices <- round(depth_area / 10000, 3)  # Areas in hectares

# Create a dataframe with the depths and areas of each slice
df_all_slices <- data.frame(Depth = depth_values, Area_ha = all_slices)

# Print the dataframe
print(df_all_slices) # <--- this is what goes into the lake.inc file


# Make the string for the lake model
bathy_input <- paste(df_all_slices$Area_ha, collapse = ", ")
bathy_input # <--- formatted for the lake.inc file




############################ Red Pond specific: separating east and west basin


# 1. Manually mask the raster after 3 meters depth
depth_threshold <- 4 #3
mask_above_threshold <- c_bathy
mask_above_threshold[c_bathy <= depth_threshold] <- NA

# Plot to visualize the area above the threshold (this should include both basins)
plot(mask_above_threshold)

# 2. Manually define the two basins
extent_basin_east <- extent(-78.9117, -78.910,  42.132, 42.1336)  # Example extent for basin 1
extent_basin_west <- extent(-78.9355, -78.9117,  42.132, 42.1340)  # Example extent for basin 2

# Mask the raster for each basin
basin_east_mask <- crop(mask_above_threshold, extent_basin_east)
basin_west_mask <- crop(mask_above_threshold, extent_basin_west)

# Plot both basins to verify
plot(basin_east_mask, main = "East Basin")
plot(basin_west_mask, main = "West Basin")

# 3. Calculate area-depth slices for each basin

# Initialize depth levels and vectors to store areas for each basin

depth_area <- numeric(nrow(rcl))

# Loop through each depth level and calculate the area
for (i in 1:nrow(rcl)) {
  depth_slice <- basin_west_mask
  
  # Mask values that are deeper than the current depth level
  depth_slice[depth_slice < i] <- NA
  
  # Check what the depth_slice looks like
  plot(depth_slice, main = paste("Depth slice at level", i))
  
  # Calculate the area for the current depth level
  result <- expanse(depth_slice, unit = 'm', transform = TRUE)
  
  # Make sure result is a scalar, sum it if it's not
  if (length(result) > 1) {
    result <- sum(result, na.rm = TRUE)
  }
  
  print(paste("Depth:", i, "Area:", result))
  
  # Assign the result to the depth_area vector
  depth_area[i] <- result
}

# Print final depth_area values
#print(round(depth_area / 10000, 3))  # Convert to hectares (ha)

print(round(depth_area[5:length(depth_area)] / 10000, 3))  # Convert to hectares (ha) and print starting from depth 4

# changed from 4 with 20 scale

# Create a dataframe with depth slices starting from 4 and their corresponding areas in hectares
depth_values <- 5:length(depth_area)  # Depth slices starting from 4
west_slices <- round(depth_area[5:length(depth_area)] / 10000, 3)  # Areas in hectares

# Create a dataframe
df_west_slices <- data.frame(Depth = depth_values, Area_ha = west_slices)

# Print the dataframe
print(df_west_slices)


# Now do east basin

depth_area <- numeric(nrow(rcl))

# Loop through each depth level and calculate the area
for (i in 1:nrow(rcl)) {
  depth_slice <- basin_east_mask
  
  # Mask values that are deeper than the current depth level
  depth_slice[depth_slice < i] <- NA
  
  # Check what the depth_slice looks like
  plot(depth_slice, main = paste("Depth slice at level", i))
  
  # Calculate the area for the current depth level
  result <- expanse(depth_slice, unit = 'm', transform = TRUE)
  
  # Make sure result is a scalar, sum it if it's not
  if (length(result) > 1) {
    result <- sum(result, na.rm = TRUE)
  }
  
  print(paste("Depth:", i, "Area:", result))
  
  # Assign the result to the depth_area vector
  depth_area[i] <- result
}

# Create a dataframe with depth slices starting from 4 and their corresponding areas in hectares
depth_values <- 5:length(depth_area)  # Depth slices starting from 4
east_slices <- round(depth_area[5:length(depth_area)] / 10000, 3)  # Areas in hectares

# Create a dataframe
df_east_slices <- data.frame(Depth = depth_values, Area_ha = east_slices)

# Print the dataframe
print(df_east_slices)



# Merge the two dataframes by the Depth column
df_basins <- merge(df_west_slices, df_east_slices, by = "Depth", suffixes = c("_west", "_east"))

# Print the combined dataframe
print(df_basins)


# Merge the two dataframes
df_combined <- merge(df_basins, df_all_slices, by = "Depth", all = TRUE)

# Fill missing values (NA) with 0 for east and west basins
df_combined$Area_ha_west[is.na(df_combined$Area_ha_west)] <- 0
df_combined$Area_ha_east[is.na(df_combined$Area_ha_east)] <- 0

# View the final combined dataframe
print(df_combined)

df_combined$Area_LAKE <- df_combined$Area_ha - df_combined$Area_ha_east
# Depth column is actually slice (bc we don't have 0m line)

# Make the string for the lake model
bathy_input <- paste(df_combined$Area_LAKE, collapse = ", ")
bathy_input





df_all_slices <- data.frame(
  Depth_interval = paste0(1:(length(all_slices)), "-", 2:length(all_slices)),  # Creating depth intervals as "1-2", "2-3", etc.
  Area_ha = df_combined$Area_LAKE  
)


print(df_all_slices)
