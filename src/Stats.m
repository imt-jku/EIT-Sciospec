classdef Stats
    methods (Static)
        function recomputeStatistics(measurementFolder, plotPath, showOnly, useRealValues)
            files = dir(fullfile(measurementFolder, '*.txt'));
            if isempty(files)
                error('No measurement files found in the specified directory.');
            end
        
            accumulatedData = struct();
            noiseFloor = struct();
        
            for i = 1:length(files)
                filePath = fullfile(files(i).folder, files(i).name);
                [dataMatrices, measurementCurrent, measurementFrequencies, ...
                    measurementChannels, inputChannels, outputChannels, patternType, isLogScale] = ...
                    Data.parseMeasurementDataWithHeader(filePath, useRealValues);

                frequencyFields = fieldnames(dataMatrices);
        
                for freqIdx = 1:length(frequencyFields)
                    freqKey = frequencyFields{freqIdx};
                    if ~isfield(accumulatedData, freqKey)
                        accumulatedData.(freqKey) = [];
                    end
                    accumulatedData.(freqKey) = cat(3, accumulatedData.(freqKey), dataMatrices.(freqKey));
                end
            end

            noiseFloorAverage = struct();
            for freqIdx = 1:length(frequencyFields)
                freqKey = frequencyFields{freqIdx};
                noiseFloor.(freqKey) = std(accumulatedData.(freqKey), 0, 3);
                noiseFloorAverage.(freqKey) = mean(noiseFloor.(freqKey), 'all');
            end
       
            Stats.plotNoiseFloor(noiseFloorAverage, plotPath, showOnly);
            Stats.plotStats(accumulatedData, plotPath, showOnly, inputChannels, outputChannels);
        end

        function plotNoiseFloor(noiseFloorAverage, plotPath, showOnly)
            frequencyFields = fieldnames(noiseFloorAverage);
            extractedFrequency = regexp(frequencyFields, '\d+', 'match');
            frequencyValues = cellfun(@(x) str2double(x{1}), extractedFrequency);
            
            [sortedFrequencyValues, sortIdx] = sort(frequencyValues);
            sortedNoiseFloorData = cell2mat(struct2cell(noiseFloorAverage));
            sortedNoiseFloorData = sortedNoiseFloorData(sortIdx);
            
            figure;
            plot(sortedFrequencyValues, sortedNoiseFloorData, '-o', 'LineWidth', 2, 'MarkerSize', 6);
            grid on;
            xlabel('Frequency (Hz)', 'FontSize', 14, 'FontWeight', 'bold');
            ylabel('Average Noise Floor (Standard Deviation)', 'FontSize', 14, 'FontWeight', 'bold');
            title('Average Noise Floor Across All Channels and Injections', 'FontSize', 16, 'FontWeight', 'bold');
            
            ax = gca;
            ax.XScale = 'log'; 
            ax.FontSize = 12; 

            if (~showOnly)
                saveas(gcf, fullfile(plotPath, 'average_noise_floor.png'));
            end
        end


        function plotStats(data, basePath, showOnly, inputChannels, outputChannels)
            frequencyFields = fieldnames(data);
            for idx = 1:length(frequencyFields)
                freqKey = frequencyFields{idx};
                freqData = data.(freqKey);
                
                extractedFrequency = regexp(freqKey, '\d+', 'match');
                frequencyValue = str2double(extractedFrequency{1});
                numSamples = size(freqData, 3);
                
                figure;
                set(gcf, 'Units', 'normalized', 'Position', [0, 0, 1, 0.9]);
                
                leftMargin = 0.05;
                widthPerPlot = 0.4;
                spaceBetweenPlots = 0.05;
                plotHeight = 0.4;
                bottomMargin = 0.1;
        
                % Plot Mean Values
                ax1 = subplot(2, 2, 1);
                Stats.plotMatrix(mean(real(freqData), 3), 'Mean Values', inputChannels, outputChannels);
                set(ax1, 'Position', [leftMargin, bottomMargin + plotHeight + spaceBetweenPlots, widthPerPlot, plotHeight]);
        
                % Plot Standard Deviation
                ax2 = subplot(2, 2, 2);
                Stats.plotMatrix(std(real(freqData), 0, 3), 'Standard Deviation', inputChannels, outputChannels);
                set(ax2, 'Position', [leftMargin + widthPerPlot + spaceBetweenPlots, bottomMargin + plotHeight + spaceBetweenPlots, widthPerPlot, plotHeight]);
        
                % Plot Range (Max - Min)
                ax3 = subplot(2, 2, 3);
                Stats.plotMatrix(max(real(freqData), [], 3) - min(real(freqData), [], 3), 'Range (Max-Min)', inputChannels, outputChannels);
                set(ax3, 'Position', [leftMargin, bottomMargin, widthPerPlot, plotHeight]);
        
                % Calculate and Plot Variance
                ax4 = subplot(2, 2, 4);
                varianceValues = var(real(freqData), 0, 3);
                Stats.plotMatrix(varianceValues, 'Variance', inputChannels, outputChannels);
                set(ax4, 'Position', [leftMargin + widthPerPlot + spaceBetweenPlots, bottomMargin, widthPerPlot, plotHeight]);
        
                % Add legend
                hold on;
                hInjLegend = plot(nan, nan, 'X', 'Color', 'b', 'MarkerSize', 18, 'LineWidth', 2);
                hMeasLegend = plot(nan, nan, 'O', 'Color', 'b', 'MarkerSize', 18, 'LineWidth', 2);
                legend([hInjLegend, hMeasLegend], {'Injection Point', 'Output Point'}, ...
                       'Position', [0.5 - 0.15/2, 0.02, 0.15, 0.1], 'Units', 'normalized', 'FontSize', 18, 'FontWeight', 'bold');
                hold off;
        
                sgtitle(sprintf('Statistics (real) %.2f Hz (Samples: %d)', frequencyValue, numSamples), 'FontSize', 22, 'FontWeight', 'bold');
        
   
                if ~showOnly
                    filename = sprintf('%s/Real_%.2fHz_Samples_%d.png', basePath, frequencyValue, numSamples);
                    saveas(gcf, filename);
                    close(gcf);
                else
                    waitfor(gcf);
                end
        
                figure;
                set(gcf, 'Units', 'normalized', 'Position', [0, 0, 1, 0.9]);
    
                % Plot Mean Values
                ax1 = subplot(2, 2, 1);
                Stats.plotMatrix(mean(imag(freqData), 3), 'Mean Values', inputChannels, outputChannels);
                set(ax1, 'Position', [leftMargin, bottomMargin + plotHeight + spaceBetweenPlots, widthPerPlot, plotHeight]);
    
                % Plot Standard Deviation
                ax2 = subplot(2, 2, 2);
                Stats.plotMatrix(std(imag(freqData), 0, 3), 'Standard Deviation', inputChannels, outputChannels);
                set(ax2, 'Position', [leftMargin + widthPerPlot + spaceBetweenPlots, bottomMargin + plotHeight + spaceBetweenPlots, widthPerPlot, plotHeight]);
    
                % Plot Range (Max - Min)
                ax3 = subplot(2, 2, 3);
                Stats.plotMatrix(max(imag(freqData), [], 3) - min(imag(freqData), [], 3), 'Range (Max-Min)', inputChannels, outputChannels);
                set(ax3, 'Position', [leftMargin, bottomMargin, widthPerPlot, plotHeight]);
    
                % Calculate and Plot Variance 
                ax4 = subplot(2, 2, 4);
                varianceValues = var(imag(freqData), 0, 3);
                Stats.plotMatrix(varianceValues, 'Variance', inputChannels, outputChannels);
                set(ax4, 'Position', [leftMargin + widthPerPlot + spaceBetweenPlots, bottomMargin, widthPerPlot, plotHeight]);
    
                hold on;
                hInjLegend = plot(nan, nan, 'X', 'Color', 'b', 'MarkerSize', 18, 'LineWidth', 2);
                hMeasLegend = plot(nan, nan, 'O', 'Color', 'b', 'MarkerSize', 18, 'LineWidth', 2);
                legend([hInjLegend, hMeasLegend], {'Injection Point', 'Output Point'}, ...
                       'Position', [0.5 - 0.15/2, 0.02, 0.15, 0.1], 'Units', 'normalized', 'FontSize', 18, 'FontWeight', 'bold');
                hold off;
    
                sgtitle(sprintf('Statistics (imaginary) %.2f Hz (Samples: %d)', frequencyValue, numSamples), 'FontSize', 22, 'FontWeight', 'bold');
    
                if ~showOnly
                    filename = sprintf('%s/Imaginary_%.2fHz_Samples_%d.png', basePath, frequencyValue, numSamples);
                    saveas(gcf, filename);
                    close(gcf);
                else
                    waitfor(gcf);
                end
            end
        end

        function plotMatrix(matrix, label, inputChannels, outputChannels)
            imagesc(matrix);
            title(label, 'FontSize', 18, 'FontWeight', 'bold');
            colormap('hot');
            colorbar;
            axis square;
        
            ax = gca;
            [numRows, numCols] = size(matrix);
        
            ax.XTick = 1:numCols;
            ax.YTick = 1:numRows;
            ax.XTickLabelRotation = 45;
            ax.YTickLabelRotation = 0;
            ax.FontSize = 14;
        
            hold on;
            minDimension = min(length(inputChannels), numRows);
            for i = 1:minDimension
                text(inputChannels(i), i, 'X', 'Color', 'b', 'FontSize', 18, ...
                     'HorizontalAlignment', 'center', 'FontWeight', 'bold');
        
                text(outputChannels(i), i, 'O', 'Color', 'b', 'FontSize', 18, ...
                     'HorizontalAlignment', 'center', 'FontWeight', 'bold');
            end
            hold off;
        end
    end
end
