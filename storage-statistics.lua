#!/usr/bin/env luajit

-- Primarily written by ChatGPT using GPT-3.5, with corrections and modifications by me.
-- Do whatever the hell you want with it.

local lfs = require "lfs"

-- Function to get the filesize of a given file
function get_filesize(filepath)
    local file = io.open(filepath, "rb")
    if file then
        local size = file:seek("end")
        file:close()
        return size
    else
        return nil
    end
end

-- Function to recursively traverse directories and get file sizes
function traverse_directory(path)
    local total_size = 0
    local total_files = 0
    local file_sizes = {}

    for entry in lfs.dir(path) do
        if entry ~= "." and entry ~= ".." then
            local full_path = path..'\\'..entry
            local attributes = lfs.attributes(full_path)

            if attributes and attributes.mode == "file" then
                local size = get_filesize(full_path)

                if size then
                    print(full_path, size, "bytes")
                    table.insert(file_sizes, size)
                    total_size = total_size + size
                    total_files = total_files + 1
                else
                    print(full_path, "File not found or inaccessible")
                end
            elseif attributes and attributes.mode == "directory" then
                local subdir_total_size, subdir_total_files, subdir_file_sizes = traverse_directory(full_path)
                total_size = total_size + subdir_total_size
                total_files = total_files + subdir_total_files
                while #subdir_file_sizes > 0 do
                    table.insert(file_sizes, table.remove(subdir_file_sizes))
                end
            end
        end
    end

    return total_size, total_files, file_sizes
end

-- Function to calculate evenly spaced percentiles
function calculate_percentiles(data, num_percentiles)
    local result = {}
    table.sort(data)

    for i = 1, num_percentiles do
        local p = (i - 1) / (num_percentiles - 1) * 100
        local index = math.ceil(#data * p / 100)
        if index == 0 then index = 1 end
        result[i] = data[index]
    end

    return result
end

-- Function to print percentiles table returned from calculate_percentiles
function print_percentiles(percentiles)
    for i, value in pairs(percentiles) do
        local p = (i - 1) / (#percentiles - 1) * 100
        if p == 50 then
            print(p .. "th percentile (median):", value, "bytes")
        else
            print(p .. "th percentile:", value, "bytes")
        end
    end
end

-- Function to calculate mode
function calculate_mode(data)
    local freq_map = {}
    local max_freq = 0
    local modes = {}

    for _, value in ipairs(data) do
        freq_map[value] = (freq_map[value] or 0) + 1
        if freq_map[value] > max_freq then
            max_freq = freq_map[value]
        end
    end

    if max_freq == 1 then
        return modes, max_freq -- no mode
    end

    for value, freq in pairs(freq_map) do
        if freq == max_freq then
            table.insert(modes, value)
        end
    end

    table.sort(modes)
    return modes, max_freq
end

-- Function to print mode results
function print_mode_results(modes, max_freq)
    if #modes == 0 then
        print("No mode found.")
    elseif #modes == 1 then
        print("Mode:", modes[1], "bytes")
    else
        print("Multiple modes:")
        for i, mode in ipairs(modes) do
            print("Mode " .. i .. ":", mode, "bytes")
        end
    end
    print("Frequency:", max_freq)
end

-- Function to calculate standard deviation
function calculate_standard_deviation(data)
    local n = #data
    local sum = 0
    local sum_of_squared_deviations = 0

    if n < 1 then
        return 0 -- Standard deviation is undefined for small sample sizes
    end

    -- Calculate mean
    for _, value in ipairs(data) do
        sum = sum + value
    end
    local mean = sum / n

    -- Calculate sum of squared deviations
    for _, value in ipairs(data) do
        local deviation = value - mean
        sum_of_squared_deviations = sum_of_squared_deviations + deviation^2
    end

    -- Calculate standard deviation
    local variance = sum_of_squared_deviations / (n - 1)
    local standard_deviation = math.sqrt(variance)

    return standard_deviation
end

-- Function to calculate a histogram
function calculate_histogram(data, num_bins)
    local histogram = {}
    local min_value = math.min(unpack(data))
    local max_value = math.max(unpack(data))
    local bin_width = (max_value - min_value) / num_bins

    for i = 1, num_bins do
        local bin_start = min_value + (i - 1) * bin_width
        local bin_end = bin_start + bin_width
        histogram[i] = {bin_start, bin_end, 0}
    end

    for _, value in ipairs(data) do
        local bin_index = math.floor((value - min_value) / bin_width) + 1
        if bin_index <= num_bins then
            histogram[bin_index][3] = histogram[bin_index][3] + 1
        else
            -- the largest file always calculates to an nth + 1 bin
            histogram[num_bins][3] = histogram[num_bins][3] + 1
        end
    end

    return histogram
end

-- Function to print histogram results
function print_histogram(histogram)
    for i, bin in ipairs(histogram) do
        local bin_start, bin_end, count = unpack(bin)
        print(string.format("%.2f - %.2f:", bin_start, bin_end), count, "files")
    end
end

-- Function to print histogram results with logarithmic scaling and aligned graphical representation
function print_histogram_graphical(histogram, graph_width)
    local max_count = 0

    -- Find the maximum count to determine the scale
    for _, bin in ipairs(histogram) do
        local count = bin[3]
        if count > max_count then
            max_count = count
        end
    end

    local max_log_scaled = math.log(max_count + 1) -- Add 1 to avoid log(0)

    -- Print the histogram with graphical representation and aligned text data
    for _, bin in ipairs(histogram) do
        local bin_start, bin_end, count = unpack(bin)
        local log_scaled_count = math.log(count + 1) -- Add 1 to avoid log(0)
        local scaled_width = math.floor((log_scaled_count / max_log_scaled) * graph_width) -- Adjust the width as needed

        local bar = string.rep("#", scaled_width)
        local empty_spaces = string.rep(" ", graph_width - scaled_width) -- Add empty spaces for alignment
        print(string.format("[%s%s] %.2f - %.2f: %d files", bar, empty_spaces, bin_start, bin_end, count))
    end
end

local root_directory = "." -- bodge to work in-place
local total_size, total_files, total_file_sizes = traverse_directory(root_directory)

if total_files > 0 then
    print("")
    print(total_files, "files found.")
    local average_size = total_size / total_files
    print("Average (mean) file size:", average_size, "bytes")
    local standard_deviation = calculate_standard_deviation(total_file_sizes)
    print("Standard deviation:", standard_deviation)
    local mode_results, max_freq = calculate_mode(total_file_sizes)
    print_mode_results(mode_results, max_freq)
    local bin_size = math.ceil(math.sqrt(total_files)) -- Square Root Rule
    local histogram_results = calculate_histogram(total_file_sizes, bin_size)
    print_histogram_graphical(histogram_results, 40)
    local percentiles = calculate_percentiles(total_file_sizes, 11)
    print_percentiles(percentiles)
else
    print("No files found.")
end
