classdef EITMeasurementApp < handle
    properties
        fig
        % Tab fields
        serialPortField
        baudRateField
        currentAmplitudeField
        startFrequencyField
        endFrequencyField
        frequencyCountField
        patternTypeField
        measurementNameField
        numMeasurementsField
        savePathField
        frequencySpacingField
        averagingField
        timeInBetweenField
        precisionField
        statusText

        % Reconstruction fields
        modelTypeField
        gridSizeField
        priorField
        solverField
        componentTypeField
        frequencyField
        hyperparameterField
        measurementsToReconstruct
        remove2WireCheckbox
        showPlots
        iterationsField

        % Other
        stopFlag = false;

        % Paths
        settingsFilePath = 'eit_measurement_settings.mat';
        defaultParams
        eidorsPath
        netgenPath
        UserData
    end

    methods
        function app = EITMeasurementApp()
            app.defaultParams = struct( ...
                'serialPort', 'COM3', 'baudRate', 9600, 'currentAmplitude', 40e-6, ...
                'startFrequency', 500, 'endFrequency', 50000, 'frequencyCount', 4, ...
                'patternType', 'Adjacent', 'measurementName', 'Default', ...
                'numMeasurements', 1, 'savePath', 'Test', 'frequencySpacing', 'Linear', ...
                'averaging', 1, 'timeInBetween', 1, 'precision', 1, ...
                'modelType', 'WaterModel', 'gridSize', 1, 'prior', 'laplace', ...
                'solver', 'Nodal', 'component', 'complex', 'frequency', '', ...
                'hyperparameter', '0.0007, 0.0006', 'measurementsToReconstruct', 1, ...
                'remove2Wire', true, 'showPlots', true,'eidorsPath', '', 'netgenPath', '', 'iterations', 3);

            if isfile(app.settingsFilePath)
                app.loadParameters();
            else
                app.setDefaultParameters(app.defaultParams);
            end

            layoutCfg.margin      = 10;
            layoutCfg.labelWidth  = 150;
            layoutCfg.fieldWidth  = 200;
            layoutCfg.controlH    = 22;
            layoutCfg.spacing     = 10;

            app.fig = uifigure('Name', 'EIT Measurement App', ...
                'Position', [100, 100, 800, 800], ...
                'CloseRequestFcn', @(src, event) app.onCloseApp());
            mainLayout = uigridlayout(app.fig, [2, 1]);
            mainLayout.RowHeight = {'1x', 80};
            mainLayout.ColumnWidth = {'1x'};
            mainLayout.Padding = [layoutCfg.margin, layoutCfg.margin, layoutCfg.margin, layoutCfg.margin];
            mainLayout.RowSpacing = layoutCfg.spacing;

            tabGroup = uitabgroup(mainLayout);
            tabGroup.Layout.Row = 1;
            tabGroup.Layout.Column = 1;

            % Measurement Tab
            measTab = uitab(tabGroup, 'Title', 'Measurement');
            app.buildMeasurementTab(measTab, layoutCfg);

            % Results Tab
            resTab = uitab(tabGroup, 'Title', 'Results');
            app.buildResultsTab(resTab, layoutCfg);
            app.statusText = uitextarea(mainLayout, 'Editable', 'off');
            app.statusText.Layout.Row = 2;
            app.statusText.Layout.Column = 1;
            app.statusText.Value = 'Status: Initializing EIDORS...';

            if isempty(app.eidorsPath) || ~isfolder(app.eidorsPath) || ~exist(fullfile(app.eidorsPath, 'startup.m'), 'file')
                app.eidorsPath = uigetdir(pwd, 'Select EIDORS Directory');
                if app.eidorsPath == 0
                    error('EIDORS path is required to run the application.');
                end
                app.saveParameters();
            end

            app.initializeNetgen();
            app.initializeEidors();
        end

        function buildMeasurementTab(app, tab, cfg)
            %   1. Basic settings (serial port, baud rate, etc.)
            %   2. Additional measurement settings (measurement name, number, etc.)
            %   3. Buttons

            % Section 1: Basic Settings
            measLayout = uigridlayout(tab, [3, 1]);
            measLayout.Padding = [cfg.margin, cfg.margin, cfg.margin, cfg.margin];
            measLayout.RowSpacing = cfg.spacing;
            measLayout.RowHeight = {'1x', '1x', 50};  % last row for buttons

            % Grid for basic fields (serial port, baud rate, etc.)
            basicGrid = uigridlayout(measLayout, [8, 3]);
            basicGrid.Layout.Row = 1;
            basicGrid.Layout.Column = 1;
            basicGrid.Padding = [cfg.margin, cfg.margin, cfg.margin, cfg.margin];
            basicGrid.RowSpacing = cfg.spacing;
            basicGrid.ColumnSpacing = cfg.spacing;
            basicGrid.ColumnWidth = {cfg.labelWidth, cfg.fieldWidth, 80};
            basicGrid.RowHeight = repmat({cfg.controlH}, 1, 8);

            % Row 1: Serial Port + Refresh Button
            uilabel(basicGrid, 'Text', 'Serial Port:', 'HorizontalAlignment', 'right');
            availablePorts = serialportlist("all");
            if isempty(availablePorts)
                availablePorts = {'No Ports Available'};
            end
            if ismember(app.serialPortField.Value, availablePorts)
                defaultPort = app.serialPortField.Value;
            else
                defaultPort = availablePorts{1};
            end
            app.serialPortField = uidropdown(basicGrid, 'Items', availablePorts, 'Value', defaultPort);
            uibutton(basicGrid, 'Text', 'Refresh', 'ButtonPushedFcn', @(btn, event) app.refreshSerialPorts());

            % Row 2: Baud Rate
            uilabel(basicGrid, 'Text', 'Baud Rate:', 'HorizontalAlignment', 'right');
            app.baudRateField = uieditfield(basicGrid, 'numeric', 'Value', app.baudRateField.Value);
            uilabel(basicGrid, 'Text', '');

            % Row 3: Current Amplitude
            uilabel(basicGrid, 'Text', 'Current Amplitude (A):', 'HorizontalAlignment', 'right');
            app.currentAmplitudeField = uieditfield(basicGrid, 'numeric', 'Value', app.currentAmplitudeField.Value);
            uilabel(basicGrid, 'Text', '');

            % Row 4: Start Frequency
            uilabel(basicGrid, 'Text', 'Start Frequency (Hz):', 'HorizontalAlignment', 'right');
            app.startFrequencyField = uieditfield(basicGrid, 'numeric', 'Value', app.startFrequencyField.Value);
            uilabel(basicGrid, 'Text', '');

            % Row 5: End Frequency
            uilabel(basicGrid, 'Text', 'End Frequency (Hz):', 'HorizontalAlignment', 'right');
            app.endFrequencyField = uieditfield(basicGrid, 'numeric', 'Value', app.endFrequencyField.Value);
            uilabel(basicGrid, 'Text', '');

            % Row 6: Frequency Count
            uilabel(basicGrid, 'Text', 'Frequency Count:', 'HorizontalAlignment', 'right');
            app.frequencyCountField = uieditfield(basicGrid, 'numeric', 'Value', app.frequencyCountField.Value);
            uilabel(basicGrid, 'Text', '');

            % Row 7: Frequency Spacing
            uilabel(basicGrid, 'Text', 'Frequency Spacing:', 'HorizontalAlignment', 'right');
            app.frequencySpacingField = uidropdown(basicGrid, 'Items', {'Linear', 'Logarithmic'}, 'Value', app.frequencySpacingField.Value);
            uilabel(basicGrid, 'Text', '');

            % Row 8: Pattern Type + Info Button
            uilabel(basicGrid, 'Text', 'Pattern Type:', 'HorizontalAlignment', 'right');
            app.patternTypeField = uidropdown(basicGrid, 'Items', {'Adjacent', 'Diagonal', 'Opposite', 'Hybrid', 'Montgomery'}, 'Value', app.patternTypeField.Value);
            infoIconPath = fullfile('src', 'patterns', 'info.png');
            uibutton(basicGrid, 'Text', '', 'Icon', infoIconPath, 'ButtonPushedFcn', @(btn, event) app.showPatternInfo());

            % Section 2: Additional Measurement Settings
            additionalGrid = uigridlayout(measLayout, [6, 2]);
            additionalGrid.Layout.Row = 2;
            additionalGrid.Layout.Column = 1;
            additionalGrid.Padding = [cfg.margin, cfg.margin, cfg.margin, cfg.margin];
            additionalGrid.RowSpacing = cfg.spacing;
            additionalGrid.ColumnSpacing = cfg.spacing;
            additionalGrid.ColumnWidth = {cfg.labelWidth, cfg.fieldWidth};
            additionalGrid.RowHeight = repmat({cfg.controlH}, 1, 6);

            % Row 1: Measurement Name
            uilabel(additionalGrid, 'Text', 'Measurement Name:', 'HorizontalAlignment', 'right');
            app.measurementNameField = uieditfield(additionalGrid, 'text', 'Value', app.measurementNameField.Value);

            % Row 2: Number of Measurements
            uilabel(additionalGrid, 'Text', 'Number of Measurements:', 'HorizontalAlignment', 'right');
            app.numMeasurementsField = uieditfield(additionalGrid, 'numeric', 'Value', app.numMeasurementsField.Value);

            % Row 3: Save Path
            uilabel(additionalGrid, 'Text', 'Save Path:', 'HorizontalAlignment', 'right');
            app.savePathField = uieditfield(additionalGrid, 'text', 'Value', app.savePathField.Value);

            % Row 4: Time Between Measurements
            uilabel(additionalGrid, 'Text', 'Time Between Measurements (s):', 'HorizontalAlignment', 'right');
            app.timeInBetweenField = uieditfield(additionalGrid, 'numeric', 'Value', app.timeInBetweenField.Value, 'Limits', [0, 1000]);

            % Row 5: Averaging Count
            uilabel(additionalGrid, 'Text', 'Averaging Count:', 'HorizontalAlignment', 'right');
            app.averagingField = uieditfield(additionalGrid, 'numeric', 'Value', app.averagingField.Value, 'Limits', [1, 100]);

            % Row 6: Precision
            uilabel(additionalGrid, 'Text', 'Precision:', 'HorizontalAlignment', 'right');
            app.precisionField = uieditfield(additionalGrid, 'numeric', 'Value', app.precisionField.Value, 'Limits', [1, 5]);

            % Section 3: Buttons
            btnLayout = uigridlayout(measLayout, [1, 3]);
            btnLayout.Layout.Row = 3;
            btnLayout.Layout.Column = 1;
            btnLayout.Padding = [cfg.margin, cfg.margin, cfg.margin, cfg.margin];
            btnLayout.ColumnSpacing = cfg.spacing;
            btnLayout.ColumnWidth = {'1x', '1x', '1x'};

            uibutton(btnLayout, 'Text', 'Test Connection', ...
                'ButtonPushedFcn', @(btn, event) app.testConnectionCallback());
            uibutton(btnLayout, 'Text', 'Run Measurement', ...
                'ButtonPushedFcn', @(btn, event) app.runMeasurementCallback());
            uibutton(btnLayout, 'Text', 'Continuous', ...
                'ButtonPushedFcn', @(btn, event) app.continuousMeasurementCallback());
        end

        function buildResultsTab(app, tab, cfg)
            % Create a main grid layout
            resLayout = uigridlayout(tab, [2, 1]);
            resLayout.Padding = [cfg.margin, cfg.margin, cfg.margin, cfg.margin];
            resLayout.RowSpacing = cfg.spacing;
            resLayout.ColumnSpacing = cfg.spacing;
            resLayout.RowHeight = {'1x', 50};

            fieldsGrid = uigridlayout(resLayout, [12, 2]);
            fieldsGrid.Layout.Row = 1;
            fieldsGrid.Layout.Column = 1;
            fieldsGrid.Padding = [cfg.margin, cfg.margin, cfg.margin, cfg.margin];
            fieldsGrid.RowSpacing = cfg.spacing;
            fieldsGrid.ColumnSpacing = cfg.spacing;
            fieldsGrid.ColumnWidth = {cfg.labelWidth, cfg.fieldWidth};
            fieldsGrid.RowHeight = repmat({cfg.controlH}, 1, 12);

            % -- Row 1: Model Type
            uilabel(fieldsGrid, 'Text', 'Select Model:', ...
                'HorizontalAlignment', 'right');
            app.modelTypeField = uidropdown(fieldsGrid, ...
                'Items', {'WaterModel','ElastomerModel','CircularModel'}, ...
                'Value', app.modelTypeField.Value);

            % -- Row 2: Grid Size
            uilabel(fieldsGrid, 'Text', 'Grid Size:', ...
                'HorizontalAlignment', 'right');
            app.gridSizeField = uieditfield(fieldsGrid, 'numeric', ...
                'Value', app.gridSizeField.Value);

            % -- Row 3: Prior
            uilabel(fieldsGrid, 'Text', 'Select Prior:', ...
                'HorizontalAlignment', 'right');
            app.priorField = uidropdown(fieldsGrid, ...
                'Items', {'laplace','noser','tikhonov','gaussian','TV'}, ...
                'Value', app.priorField.Value);

            % -- Row 4: Solver
            uilabel(fieldsGrid, 'Text', 'Select Solver:', ...
                'HorizontalAlignment', 'right');
            app.solverField = uidropdown(fieldsGrid, ...
                'Items', {'Nodal','Gauss-Newton-ON','Gauss-Newton-iterative','Dual','TV'}, ...
                'Value', app.solverField.Value);

            % -- Row 5: Component Type
            uilabel(fieldsGrid, 'Text', 'Component Type:', ...
                'HorizontalAlignment', 'right');
            app.componentTypeField = uidropdown(fieldsGrid, ...
                'Items', {'complex','imaginary','real'}, ...
                'Value', app.componentTypeField.Value);

            % -- Row 6: Frequency
            uilabel(fieldsGrid, 'Text', 'Select Frequency:', ...
                'HorizontalAlignment', 'right');
            app.frequencyField = uidropdown(fieldsGrid, ...
                'Items', {'No measurement loaded'}, ...
                'Value', 'No measurement loaded');

            % -- Row 7: Hyperparameters
            uilabel(fieldsGrid, 'Text', 'Hyperparameters:', ...
                'HorizontalAlignment', 'right');
            app.hyperparameterField = uieditfield(fieldsGrid, 'text', ...
                'Value', app.hyperparameterField.Value);

            % -- Row 8: No. of Measurements
            uilabel(fieldsGrid, 'Text', 'No. of Measurements:', ...
                'HorizontalAlignment', 'right');
            app.measurementsToReconstruct = uieditfield(fieldsGrid, 'numeric', ...
                'Value', app.measurementsToReconstruct.Value);

            % -- Row 9: Save Path
            uilabel(fieldsGrid, 'Text', 'Save Path:', ...
                'HorizontalAlignment', 'right');
            app.savePathField = uieditfield(fieldsGrid, 'text', ...
                'Value', app.savePathField.Value);

            % -- Row 10: Iterations
            uilabel(fieldsGrid, 'Text', 'Iterations:', ...
                'HorizontalAlignment', 'right');
            app.iterationsField = uieditfield(fieldsGrid, 'numeric', ...
                'Value', app.iterationsField.Value);

            % -- Row 11: Remove 2-Wire Checkbox
            uilabel(fieldsGrid, 'Text', '');
            app.remove2WireCheckbox = uicheckbox(fieldsGrid, ...
                'Text', 'Remove 2-Wire Measurements', ...
                'Value', app.remove2WireCheckbox.Value);

            % -- Row 12: Show plot
            uilabel(fieldsGrid, 'Text', '');
            app.showPlots = uicheckbox(fieldsGrid, ...
                'Text', 'Show Plots', ...
                'Value', app.showPlots.Value);

            btnLayout = uigridlayout(resLayout, [1, 3]);
            btnLayout.Layout.Row = 2;
            btnLayout.Layout.Column = 1;
            btnLayout.Padding = [cfg.margin, cfg.margin, cfg.margin, cfg.margin];
            btnLayout.ColumnSpacing = cfg.spacing;
            btnLayout.ColumnWidth = {'1x', '1x', '1x'};

            uibutton(btnLayout, 'Text', 'Load Measurement', ...
                'ButtonPushedFcn', @(btn, event) app.loadMeasurementCallback());
            uibutton(btnLayout, 'Text', 'Plot', ...
                'ButtonPushedFcn', @(btn, event) app.plotAllMeasurementsCallback());
            uibutton(btnLayout, 'Text', 'Visualize Model', ...
                'ButtonPushedFcn', @(btn, event) app.visualizeModelCallback());
        end

        function loadMeasurementCallback(app)
            app.statusText.Value = 'Loading measurement data...';
            drawnow;

            try
                path = selectMeasurementDirectory(fullfile(pwd));
                if isempty(path) || isequal(path, 0)
                    app.statusText.Value = 'No folder selected. Operation cancelled.';
                    return;
                end

                [measurement, params] = parseMeasurementFile(path, false);
                availableFrequencies  = params.MeasurementFrequencies;

                if ~isempty(availableFrequencies)
                    freqItems = cellfun(@num2str, num2cell(availableFrequencies), 'UniformOutput', false);
                    app.frequencyField.Items = freqItems;
                    app.frequencyField.Value = freqItems{1};
                else
                    app.frequencyField.Items = {};
                    app.frequencyField.Value = '';
                end

                totalMeas = length(params.MeasurementNames);
                app.measurementsToReconstruct.Value = totalMeas;

                app.statusText.Value = 'Measurement data loaded. Adjust settings and click Plot or Visualize Model.';
                app.UserData.loadedMeasurement = measurement;
                app.UserData.loadedParams      = params;

            catch ME
                app.statusText.Value = sprintf('Error: %s', ME.message);
            end
        end

        function initializeNetgen(app)
            if ismac
                while true
                    if isempty(app.netgenPath) || ~isfolder(app.netgenPath) || ~exist(fullfile(app.netgenPath, 'netgen'), 'file')
                        app.netgenPath = uigetdir(pwd, 'Select Netgen Directory');
                        if app.netgenPath == 0
                            warning('Netgen path is required to run the application on macOS. Please select a valid directory.');
                        else
                            app.saveParameters();
                            break;
                        end
                    else
                        break;
                    end
                end
            else
                app.netgenPath = '';
            end
        end

        function initializeEidors(app)
            % Initialize EIDORS
            eidorsStartupPath = fullfile(app.eidorsPath, 'startup.m');
            netgenDirPath = app.netgenPath;

            if exist(eidorsStartupPath, 'file')
                app.setup_eidors(eidorsStartupPath, netgenDirPath);
            else
                warning('EIDORS startup.m file not found in the specified path.');
            end
            app.statusText.Value = 'EIDORS initialized. Ready to use.';
        end

        function setDefaultParameters(app, defaultParams)
            % default params for measurement
            app.serialPortField.Value = defaultParams.serialPort;
            app.baudRateField.Value = defaultParams.baudRate;
            app.currentAmplitudeField.Value = defaultParams.currentAmplitude;
            app.startFrequencyField.Value = defaultParams.startFrequency;
            app.endFrequencyField.Value = defaultParams.endFrequency;
            app.frequencyCountField.Value = defaultParams.frequencyCount;
            app.patternTypeField.Value = defaultParams.patternType;
            app.measurementNameField.Value = defaultParams.measurementName;
            app.numMeasurementsField.Value = defaultParams.numMeasurements;
            app.savePathField.Value = defaultParams.savePath;
            app.frequencySpacingField.Value = defaultParams.frequencySpacing;
            app.averagingField.Value = defaultParams.averaging;
            app.timeInBetweenField.Value = defaultParams.timeInBetween;
            app.precisionField.Value = defaultParams.precision;


            % default params for reconstruction
            app.modelTypeField.Value = defaultParams.modelType;
            app.gridSizeField.Value = defaultParams.gridSize;
            app.priorField.Value = defaultParams.prior;
            app.solverField.Value = defaultParams.solver;
            app.componentTypeField.Value = defaultParams.component;
            app.frequencyField.Value = defaultParams.frequency;
            app.hyperparameterField.Value = defaultParams.hyperparameter;
            app.measurementsToReconstruct.Value = defaultParams.measurementsToReconstruct;
            app.remove2WireCheckbox.Value = defaultParams.remove2Wire;
            app.showPlots.Value = defaultParams.showPlots;
            app.iterationsField.Value = defaultParams.iterations;
        end

        function loadParameters(app)
            % Load parameter values from file if it exists
            if isfile(app.settingsFilePath)
                loadedData = load(app.settingsFilePath, 'params');
                params = loadedData.params;

                app.serialPortField.Value = params.serialPort;
                app.baudRateField.Value = params.baudRate;
                app.currentAmplitudeField.Value = params.currentAmplitude;
                app.startFrequencyField.Value = params.startFrequency;
                app.endFrequencyField.Value = params.endFrequency;
                app.frequencyCountField.Value = params.frequencyCount;
                app.patternTypeField.Value = params.patternType;
                app.measurementNameField.Value = params.measurementName;
                app.numMeasurementsField.Value = params.numMeasurements;
                app.savePathField.Value = params.savePath;
                app.frequencySpacingField.Value = params.frequencySpacing;
                app.averagingField.Value = params.averaging;
                app.timeInBetweenField.Value = params.timeInBetween;
                app.precisionField.Value = params.precision;

                app.modelTypeField.Value = params.modelType;
                app.gridSizeField.Value = params.gridSize;
                app.priorField.Value = params.prior;
                app.solverField.Value = params.solver;
                app.componentTypeField.Value = params.component;
                app.frequencyField.Value = params.frequency;
                app.hyperparameterField.Value = params.hyperparameter;
                app.measurementsToReconstruct.Value = params.measurementsToReconstruct;
                app.remove2WireCheckbox.Value = params.remove2Wire;
                app.showPlots.Value = params.showPlots;
                app.iterationsField.Value = params.iterationsField;
                app.eidorsPath = params.eidorsPath;
                app.netgenPath = params.netgenPath;
            else
                app.setDefaultParameters(app.defaultParams);
            end
        end

        function onCloseApp(app)
            app.saveParameters();
            delete(app.fig);
        end

        function saveParameters(app)
            % Save measurement settings
            params.serialPort = app.serialPortField.Value;
            params.baudRate = app.baudRateField.Value;
            params.currentAmplitude = app.currentAmplitudeField.Value;
            params.startFrequency = app.startFrequencyField.Value;
            params.endFrequency = app.endFrequencyField.Value;
            params.frequencyCount = app.frequencyCountField.Value;
            params.patternType = app.patternTypeField.Value;
            params.measurementName = app.measurementNameField.Value;
            params.numMeasurements = app.numMeasurementsField.Value;
            params.savePath = app.savePathField.Value;
            params.frequencySpacing = app.frequencySpacingField.Value;
            params.averaging = app.averagingField.Value;
            params.timeInBetween = app.timeInBetweenField.Value;
            params.precision = app.precisionField.Value;

            % Save reconstruction settings
            params.modelType = app.modelTypeField.Value;
            params.gridSize = app.gridSizeField.Value;
            params.prior = app.priorField.Value;
            params.solver = app.solverField.Value;
            params.component = app.componentTypeField.Value;
            params.frequency = app.frequencyField.Value;
            params.hyperparameter = app.hyperparameterField.Value;
            params.measurementsToReconstruct = app.measurementsToReconstruct.Value;
            params.remove2Wire = app.remove2WireCheckbox.Value;
            params.showPlots = app.showPlots.Value;
            params.iterationsField = app.iterationsField.Value;

            params.eidorsPath = app.eidorsPath;
            params.netgenPath = app.netgenPath;
            save(app.settingsFilePath, 'params');
        end


        function continuousMeasurementCallback(app)
            % continuous measurement settings
            settingsFig = uifigure('Name', 'Continuous Measurement Settings');

            gl = uigridlayout(settingsFig, [7, 2]);
            gl.Padding = [10, 10, 10, 10];
            gl.RowSpacing = 10;
            gl.ColumnSpacing = 10;
            gl.ColumnWidth = {150, 200};

            % Row 1: Select Model
            uilabel(gl, 'Text', 'Select Model:', 'HorizontalAlignment', 'right');
            app.modelTypeField = uidropdown(gl, 'Items', {'WaterModel', 'ElastomerModel', 'CircularModel'}, ...
                'Value', app.modelTypeField.Value);

            % Row 2: Grid Size
            uilabel(gl, 'Text', 'Grid Size:', 'HorizontalAlignment', 'right');
            app.gridSizeField = uieditfield(gl, 'numeric', 'Value', app.gridSizeField.Value, 'Limits', [0.1, 10]);

            % Row 3: Select Prior
            uilabel(gl, 'Text', 'Select Prior:', 'HorizontalAlignment', 'right');
            app.priorField = uidropdown(gl, 'Items', {'laplace', 'noser', 'tikhonov', 'gaussian', 'TV'}, ...
                'Value', app.priorField.Value);

            % Row 4: Select Solver
            uilabel(gl, 'Text', 'Select Solver:', 'HorizontalAlignment', 'right');
            app.solverField = uidropdown(gl, 'Items', {'Nodal', 'Gauss-Newton-ON', 'Gauss-Newton-iterative', 'Dual', 'TV'}, ...
                'Value', app.solverField.Value);

            % Row 5: Component Type
            uilabel(gl, 'Text', 'Component Type:', 'HorizontalAlignment', 'right');
            app.componentTypeField = uidropdown(gl, 'Items', {'complex', 'imaginary', 'real'}, ...
                'Value', app.componentTypeField.Value);

            % Row 6: Hyperparameters
            uilabel(gl, 'Text', 'Hyperparameters:', 'HorizontalAlignment', 'right');
            app.hyperparameterField = uieditfield(gl, 'text', 'Value', app.hyperparameterField.Value);

            buttonLayout = uigridlayout(gl, [1, 2]);
            buttonLayout.Layout.Row = 7;
            buttonLayout.Layout.Column = [1 2];
            buttonLayout.ColumnSpacing = 10;
            buttonLayout.ColumnWidth = {'1x', '1x'};

            uibutton(buttonLayout, 'Text', 'Start Measurement', ...
                'ButtonPushedFcn', @(btn,event) app.startContinuousMeasurement());
            uibutton(buttonLayout, 'Text', 'Stop Measurement', ...
                'ButtonPushedFcn', @(btn,event) app.stopContinuousMeasurement());

            settingsFig.Position = [150, 150, 400, 450];
            app.statusText.Value = 'Select settings for continuous measurement.';
        end


        function stopContinuousMeasurement(app)
            app.stopFlag = true;
            app.statusText.Value = 'Stopping measurement...';
            drawnow;
        end

        function saveSettingsOnClose(app, src)
            try
                app.saveParameters();
                delete(src);
            catch ME
                warning('%s: %s', ME.identifier, ME.message);
            end
        end

        function startContinuousMeasurement(app)
            try
                serialPort = app.serialPortField.Value;
                baudRate = app.baudRateField.Value;
                currentAmplitude = app.currentAmplitudeField.Value;
                startFrequency = app.startFrequencyField.Value;
                endFrequency = app.endFrequencyField.Value;
                frequencyCount = app.frequencyCountField.Value;
                patternType = app.patternTypeField.Value;
                measurementName = app.measurementNameField.Value;
                numMeasurements = app.numMeasurementsField.Value;
                savePath = app.savePathField.Value;
                frequencySpacing = app.frequencySpacingField.Value;
                precision = app.precisionField.Value;
                averaging = app.averagingField.Value;

                modelType = app.modelTypeField.Value;
                gridSize = app.gridSizeField.Value;
                componentType = app.componentTypeField.Value;

                app.statusText.Value = 'Running Continuous EIT Measurement...';
                drawnow;

                useLog = strcmp(frequencySpacing, 'Logarithmic');

                measurementNames = arrayfun(@(x) sprintf('%s_%d', measurementName, x), 1:numMeasurements, 'UniformOutput', false);

                e = EIT();
                e = e.setupScioSpecConnection(serialPort, baudRate);
                e = e.configureConnectionHandler(1, currentAmplitude, startFrequency, endFrequency, frequencyCount, useLog, precision, 16, patternType);
                e = e.setSavePath(savePath);
                e.connectionHandler.sendEITSetup();

                currentDateTime = datetime('now', 'Format', 'yyyy-MM-dd_HH-mm-ss');
                baseFolderName = fullfile(savePath, patternType, char(currentDateTime));
                mkdir(baseFolderName);

                filePath = fullfile(baseFolderName, measurementNames{1});

                baselineSumMatrix = struct();
                avMatrix = 0;
                for i = 1:averaging
                    [curBaseMatrix, ~, ~, channels, inputChannels, outputChannels, ~, ~] = e.continousMeasurement(filePath);
                    frequencies = fieldnames(curBaseMatrix);
                    f = frequencies{1};
                    matrix = curBaseMatrix.(f);
                    avMatrix = avMatrix + matrix;
                    fprintf('Baseline measurement %d completed.\n', i);
                end
                avMatrix = avMatrix / averaging;
                baselineSumMatrix.(f)= avMatrix;
                disp('Averaged baseline measurement completed.');

                fwdModel = app.getfwdModel(modelType, gridSize);
                fwdModel = Model.setStimulation(fwdModel, inputChannels, outputChannels, channels, currentAmplitude, true);

                bMatrix = Data.convertToAdjacentMatrixForFirstFrequency(baselineSumMatrix);
                baseLineVec = Reconstruction.buildEidorsDataForMeasurement(bMatrix, measurementNames{1}, componentType, fwdModel);

                disp('Baseline measurement completed.');

                if isempty(gcp('nocreate'))
                    parpool('local');
                end

                app.stopFlag = false;
                i=1;
                while true
                    if app.stopFlag
                        app.statusText.Value = 'Measurement stopped by user.';
                        break;
                    end

                    filePath = fullfile(baseFolderName, measurementNames{i});
                    app.statusText.Value = sprintf('Running Measurement %d of %d...', i, numMeasurements);
                    drawnow;

                    curMatrix = e.continousMeasurement(filePath);
                    curMatrix = Data.convertToAdjacentMatrixForFirstFrequency(curMatrix);
                    curVec = Reconstruction.buildEidorsDataForMeasurement(curMatrix, measurementNames{i}, componentType, fwdModel);
                    fprintf('Measurement %d completed.\n', i);

                    app.updateSinglePlotWithMeasurement(curVec, baseLineVec, fwdModel);
                    i = i + 1;
                end

                if ~app.stopFlag
                    app.statusText.Value = 'Continuous EIT Measurement Completed.';
                end

            catch ME
                warning('%s: %s', ME.identifier, ME.message);
            end
        end

        function updateSinglePlotWithMeasurement(app, curEidorsData, baseLineEidorsData, fwdModel)
            persistent fig ax invModel data1

            try
                if isempty(fig) || ~isvalid(fig)
                    fig = figure('Name', 'EIT Reconstruction', 'NumberTitle', 'off', 'Visible', 'on');
                    ax = axes(fig);
                    hold(ax, 'on');

                    disp('Figure and axes created for EIT Reconstruction.');

                    priorType = app.priorField.Value;
                    solverType = app.solverField.Value;
                    hyperparameters = strsplit(app.hyperparameterField.Value, ',');
                    hyperparameterValues = cellfun(@(x) str2double(x), hyperparameters, 'UniformOutput', false);

                    prior = Reconstruction.setPriors(priorType);
                    solver = Reconstruction.setSolver(solverType);
                    hyperparameter = hyperparameterValues{1};

                    disp(['Prior type: ', priorType, ', Solver type: ', solverType, ', Hyperparameter: ', num2str(hyperparameter)]);

                    invModel = Reconstruction.createInverseModel(1, solver{1}, prior{1}, hyperparameter, fwdModel, 1);

                    data1 = baseLineEidorsData;
                end

                imgr = inv_solve(invModel, data1, curEidorsData);

                disp('Inverse solve completed.');

                cla(ax);
                Reconstruction.plotDataField(imgr, fwdModel);
                colorbar(ax);
                title(ax, 'Updated Reconstruction', 'FontSize', 16);

                drawnow;

                app.statusText.Value = 'Reconstruction updated.';
                disp('Reconstruction updated.');

            catch ME
                warning('%s: %s', ME.identifier, ME.message);
            end
        end

        function runMeasurementCallback(app)
            try
                serialPort = app.serialPortField.Value;
                baudRate = app.baudRateField.Value;
                currentAmplitude = app.currentAmplitudeField.Value;
                startFrequency = app.startFrequencyField.Value;
                endFrequency = app.endFrequencyField.Value;
                frequencyCount = app.frequencyCountField.Value;
                patternType = app.patternTypeField.Value;
                measurementName = app.measurementNameField.Value;
                numMeasurements = app.numMeasurementsField.Value;
                savePath = app.savePathField.Value;
                frequencySpacing = app.frequencySpacingField.Value;
                averaging = app.averagingField.Value;
                timeInBetween = app.timeInBetweenField.Value;
                precision = app.precisionField.Value;

                app.statusText.Value = 'Running EIT Measurement...';
                drawnow;

                useLog = strcmp(frequencySpacing, 'Logarithmic');

                measurementNames = arrayfun(@(x) sprintf('%s_%d', measurementName, x), 1:numMeasurements, 'UniformOutput', false);

                e = EIT();
                e = e.setupScioSpecConnection(serialPort, baudRate);
                e = e.configureConnectionHandler(1, currentAmplitude, startFrequency, endFrequency, frequencyCount, useLog, precision, 16, patternType);

                e = e.setSavePath(savePath);

                e.startPatternedMeasurement(savePath, measurementNames, averaging, timeInBetween, measurementName);

                app.statusText.Value = 'Measurement completed.';

            catch ME
                errorMessage = sprintf('An error occurred:\n%s', ME.message);
                app.statusText.Value = errorMessage;
                disp(errorMessage);
            end
        end

        function showPatternInfo(app)
            selectedPattern = app.patternTypeField.Value;

            imageFolder = fullfile('src','patterns');
            switch selectedPattern
                case 'Adjacent'
                    imagePath = fullfile(imageFolder, 'adjacent.png');
                case 'Diagonal'
                    imagePath = fullfile(imageFolder, 'diagonal.png');
                case 'Opposite'
                    imagePath = fullfile(imageFolder, 'opposite.png');
                case 'Hybrid'
                    imagePath = fullfile(imageFolder, 'hybrid.png');
                case 'Montgomery'
                    imagePath = '';
            end

            if ~isempty(imagePath) && isfile(imagePath)
                patternFig = uifigure('Name', sprintf('%s Pattern', selectedPattern), 'Position', [100, 100, 400, 400]);
                uiimage(patternFig, 'ImageSource', imagePath, 'Position', [10, 10, 380, 380]);

            else
                uialert(app.fig, 'No image available for the selected pattern type.', 'Info');
            end
        end

        function testConnectionCallback(app)
            try
                serialPort = app.serialPortField.Value;
                baudRate = app.baudRateField.Value;
                currentAmplitude = app.currentAmplitudeField.Value;
                startFrequency = app.startFrequencyField.Value;
                endFrequency = app.endFrequencyField.Value;
                frequencyCount = app.frequencyCountField.Value;
                patternType = app.patternTypeField.Value;
                measurementName = app.measurementNameField.Value;
                numMeasurements = app.numMeasurementsField.Value;
                savePath = app.savePathField.Value;
                frequencySpacing = app.frequencySpacingField.Value;
                precision = app.precisionField.Value;

                useLog = strcmp(frequencySpacing, 'Logarithmic');
                e = EIT();
                e = e.setupScioSpecConnection(serialPort, baudRate);
                e = e.configureConnectionHandler(1, currentAmplitude, startFrequency, endFrequency, frequencyCount, useLog, precision, 16, patternType);
                e = e.setSavePath(checkAndCreateSavePath(app.savePathField.Value));
                doNotPlot = true;
                e.analyzeMultiplePatternedMeasurements(savePath, numMeasurements, patternType, measurementName, savePath, doNotPlot);
                app.statusText.Value = 'Analyzing!';
            catch ME
                app.statusText.Value = sprintf('Connection failed: %s', ME.message);
            end
            drawnow;
        end

        function plotAllMeasurementsCallback(app, measurement, params)
            if nargin < 3
                measurement = app.UserData.loadedMeasurement;
                params      = app.UserData.loadedParams;
            end

            modelType = app.modelTypeField.Value;
            gridSize = app.gridSizeField.Value;
            priorType = app.priorField.Value;
            solverType = app.solverField.Value;
            componentType = app.componentTypeField.Value;
            selectedFrequency = str2double(app.frequencyField.Value);
            showPlot = app.showPlots.Value;
            hyperparameters = strsplit(app.hyperparameterField.Value, ',');
            hyperparameterValues = cellfun(@(x) str2double(x), hyperparameters, 'UniformOutput', false);

            numMeasurements = app.measurementsToReconstruct.Value;
            iterations = app.iterationsField.Value;

            savePath = checkAndCreateSavePath(app.savePathField.Value);

            app.statusText.Value = 'Loading data and visualizing results...';
            drawnow;

            inputChannels  = params.InputChannels;
            outputChannels = params.OutputChannels;
            current        = params.MeasurementCurrent;
            frequencies    = params.MeasurementFrequencies;
            channels       = params.MeasurementChannels;

            measurements = Data.convertAllToAdjacent(measurement);

            fwdModel = app.getfwdModel(modelType, gridSize);

            fwdModel = Model.setStimulation(fwdModel, inputChannels, outputChannels, ...
                channels, current, app.remove2WireCheckbox.Value);

            frequencyIndex = find(frequencies == selectedFrequency, 1);
            if isempty(frequencyIndex)
                app.statusText.Value = 'Selected frequency is not valid.';
                return;
            end

            eidorsData = Reconstruction.createEidorsData(measurements, ...
                params, ...
                frequencyIndex, ...
                componentType, ...
                fwdModel);

            priors  = Reconstruction.setPriors(priorType);
            solvers = Reconstruction.setSolver(solverType);

            Reconstruction.plotAllMeasurements(eidorsData, ...
                numMeasurements, ...
                solvers, ...
                priors, ...
                hyperparameterValues, ...
                fwdModel, ...
                savePath, ...
                iterations, ...
                showPlot);

            app.statusText.Value = 'Visualization completed.';
        end

        function visualizeModelCallback(app)
            modelType = app.modelTypeField.Value;
            gridSize = app.gridSizeField.Value;

            fwdModel = app.getfwdModel(modelType, gridSize);
            Model.visualizeModel(fwdModel);

            app.statusText.Value = sprintf('Visualized %s model.', modelType);
        end

    end

    methods (Access = private)
        function setup_eidors(app, eidorsStartupPath, netgenDirPath)
            try
                run(eidorsStartupPath);
            catch ME
                error('Failed to run EIDORS startup script: %s', ME.message);
            end

            if ismac
                try
                    setenv('NETGENDIR', netgenDirPath);
                    setenv('PATH', [netgenDirPath, ':', getenv('PATH')]);
                catch ME
                    error('Failed to set Ne---tgen environment variables: %s', ME.message);
                end
            end

            try
                eidors_cache('cache_size', 10*1024*1024*1024);
            catch ME
                error('Failed to set EIDORS cache size: %s', ME.message);
            end

            app.statusText.Value = 'EIDORS initialized successfully.';
        end

        function fwdModel = getfwdModel(~, modelType, gridSize)
            switch modelType
                case 'WaterModel'
                    fwdModel = Model.getWaterModel(gridSize);
                case 'ElastomerModel'
                    fwdModel = Model.getElastomerModel(gridSize);
                case 'CircularModel'
                    fwdModel = Model.getCircularModel(gridSize);
            end
        end

        function refreshSerialPorts(app)
            availablePorts = serialportlist("all");
            if isempty(availablePorts)
                availablePorts = {'No Ports Available'};
            end

            app.serialPortField.Items = availablePorts;

            if ismember(app.serialPortField.Value, availablePorts)
                app.serialPortField.Value = app.serialPortField.Value;
            else
                app.serialPortField.Value = availablePorts{1};
            end

            app.statusText.Value = 'Serial ports list refreshed.';
        end
    end
end