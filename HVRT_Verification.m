%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Model Validation Result Evaluation
%% Constant Definitions: U, P, Q, Id, Iq
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Manufacturer "ADPSS_pu" data preprocessing

% Ask user to select the data type of HIL (Hardware-in-the-Loop) data
unit = input('Please enter the HIL data type, 1 for .mat format, 2 for .csv format: ');
if (unit ~= 1) && (unit ~= 2)
    error('Please enter a correct HIL data type.');
end

% Ask user to select the validation mode
unit2 = input('Please enter the validation mode, 1 for viewing results only; 2 for viewing and saving data: ');
if (unit2 ~= 1) && (unit2 ~= 2)
    error('Please enter a correct validation mode.');
end

% Initialize matrix for storing error indicators (5 variables × 9 indicators)
F_dvi = zeros(5,9);
global_variables;          % Load global variables (e.g., error thresholds, Fmax)
fig_num = 67;              % Starting figure number

disp('====== ProcessResult - ADPSS & HIL - HVRT ======');

% Time window settings for three segments (pre-fault, during-fault, post-fault)
time_set = [15000;6000;5500]/1000;   % [s] for three fault durations
% time_set = [10000;10000;10000]/1000; % alternative setting

% Y-axis labels for the five plots
y_legend = ["\itU\rm/p.u."; "\itP\rm/p.u."; "\itQ\rm/p.u."; "\itI\rm_d/p.u."; "\itI\rm_q/p.u."];

% Load file name lists (assumes FilenameCheck_HVRT defines HIL_filename and ADP_filename)
FilenameCheck_HVRT;

% Apply default figure appearance settings
Figure_Mode;

% Define paths for HIL raw data, ADPSS raw data, and exported results
path_HIL = '../m_tools/HIL_pu';
path_ADP = '../m_tools/ADPSS_Windows_pu';
path_Pro = '../m_tools/DataExport';

%% Loop over 8 test conditions
for file_category = 1:8
    % Find all files in the HIL and ADPSS directories matching the current condition
    HIL_list = dir(fullfile(path_HIL, HIL_filename{file_category}));
    ADP_list = dir(fullfile(path_ADP, ADP_filename{file_category}));
    HIL_name = {HIL_list.name};
    HIL_num = length(HIL_name);
    ADP_name = {ADP_list.name};
    ADP_num = length(ADP_name);

    %% Process each file (usually 3 files per condition: different fault durations)
    for n = 1:3
        % Construct full file paths
        HILfile = fullfile(path_HIL, HIL_name{n});
        ADPfile = fullfile(path_ADP, ADP_name{n});
        disp(['===Process ', num2str(fig_num), ': ', HIL_name{n}]);
        disp(['===ADPFile ', num2str(fig_num), ': ', ADP_name{n}]);

        % Load HIL data according to selected format
        if unit == 1
            % .mat format
            RawData = load(HILfile);
            ins = fieldnames(RawData);
            PU = RawData.(ins{:,:});   % Extract the variable (assuming it's a matrix)
            PU = PU';                   % Transpose to make time the first column
            PU(:,1) = PU(:,1) - PU(1,1); % Shift time to start at zero
        else
            % .csv format
            RawData = readtable(HILfile, 'VariableNamingRule', 'preserve');
            RawData(:,1) = RawData(:,1) - RawData(1,1); % Shift time
            PU = table2array(RawData);
            % Note: column 5 is assumed to be Iq (no modification needed)
        end

        Ts = PU(2,1) - PU(1,1); % Sampling interval

        % Load ADPSS data (always .csv)
        RawData = readtable(ADPfile, 'VariableNamingRule', 'preserve');
        RawData(:,1) = RawData(:,1) - RawData(1,1);
        PreData = table2array(RawData);

        % (Optional) Fix non-monotonic time stamps - commented out
        % for i=1:length(PreData)-1
        %     if PreData(i+1,1)-PreData(i,1) <= 0
        %         PreData(i+1,1) = PreData(i+1,1)+0.00001;
        %     end
        % end

        %% Plot comparison for each of the 5 variables (U, P, Q, Id, Iq)
        for p = 1:5
            plot(PU(:,1), PU(:,p+1))
            hold on;
            plot(PreData(:,1), PreData(:,p+1), '--')
            ax = gca;
            % Set x-axis limits based on file name (if contains '120', use 20s, else 10s)
            if strfind(HIL_name{n}, '120')
                ax.XLim = [0, 20];
            else
                ax.XLim = [0, 10];
            end

            % Set y-axis limits: voltage has narrower range
            if p == 1
                ax.YLim = [-0.2, 2];
            else
                ax.YLim = [-3, 3];
            end

            % Grid and labels
            ax.GridLineStyle = ':';
            ax.GridLineWidth = 0.5;
            grid on;
            ylabel(y_legend{p});
            xlabel('\itt\rm/s');

            % Figure positioning and legend
            set(gcf, 'WindowStyle', 'normal');
            set(gcf, 'position', [200, 200, 800, 200]);
            h = legend('HIL', 'ADPSS', 'Location', 'northoutside', 'Orientation', 'horizontal');
            set(h, 'EdgeColor', 'None');
            h.Position = h.Position - [0 0.01 0 0];
            ax.OuterPosition = [0 0 1 0.9];

            % Save figure if requested
            if unit2 == 2
                save_name = ['hvrt', num2str(fig_num), num2str(p), '.jpg'];
                saveas(gcf, fullfile(path_Pro, save_name), 'jpg');
            end
            close;
        end

        %% Data processing for error calculation

        % Determine key time indices (A, B, C) in HIL data
        % A: start of steady-state before fault
        % B: fault inception
        % C: fault clearance
        HIL_Amean = mean(PU(ceil(2/Ts):ceil(4/Ts), 2)); % mean voltage in early steady state

        try
            % Find first point where voltage exceeds 1.11 times the mean (fault detection)
            HIL_B = ceil(1.98/Ts) + find(PU(ceil(2/Ts):end, 2) > 1.11*HIL_Amean, 1);
            if isempty(HIL_B)
                HIL_B = find(PU(:,1) > 5 - 0.02, 1); % fallback to ~5s
            end
        catch
            HIL_B = find(PU(:,1) > 5 - 0.02, 1);
        end
        HIL_A = HIL_B - ceil(2/Ts); % 2 seconds before fault

        % Fault clearance time (C) based on time_set for current n
        HIL_C = find(PU(:,1) > time_set(n) - 0.02, 1);
        HIL_C2 = find(PU(:,1) > time_set(n) + 1.98, 1); % end of post-fault period (2s after clearance)
        HIL_C2t = find(PU(1:end-ceil(1/Ts), 1), 1, 'last'); % last valid index

        % Corresponding indices in ADPSS data (by time alignment)
        ADP_A = find(PreData(:,1) >= PU(HIL_A,1), 1);
        ADP_B = find(PreData(:,1) >= PU(HIL_B,1), 1);
        ADP_C = find(PreData(:,1) >= PU(HIL_C,1), 1);

        %% Loop over the five variables (U,P,Q,Id,Iq) to compute error metrics
        for nb = 2:6
            % Shift signals by +2 to avoid zero-crossing issues in comparisons
            TestHIL(:,1) = PU(:,nb) + 2;
            TestADP(:,1) = PreData(:,nb) + 2;

            % Mean values in steady-state periods
            mean_Pt  = mean(TestHIL(HIL_B + floor(0.66*(HIL_C-HIL_B)) : HIL_C));   % during fault
            mean_Ps1 = mean(TestHIL(HIL_A + floor(0.66*(HIL_B-HIL_A)) : HIL_B));   % pre-fault
            mean_Ps2 = mean(TestHIL(HIL_C2t : end));                                % post-fault (alternative)
            % mean_Ps2 = mean(TestHIL(HIL_C+floor(0.66*(HIL_C2-HIL_C)):HIL_C2));    % original commented

            % Determine boundaries for transition regions using adaptive thresholds
            comp_max1 = F_error + mean_Pt + 0.1*abs(mean_Pt - mean_Ps1);
            comp_min1 = -F_error + mean_Pt - 0.1*abs(mean_Pt - mean_Ps1);
            % Find last point where signal stays within bounds (end of transient)
            HIL_B1t = HIL_B + find(abs([0; TestHIL(HIL_B:HIL_C)]) > comp_max1 | ...
                                    abs([0; TestHIL(HIL_B:HIL_C)]) < comp_min1, 1, 'last');

            comp_max2 = F_error + mean_Ps2 + 0.1*abs(mean_Pt - mean_Ps2);
            comp_min2 = -F_error + mean_Ps2 - 0.1*abs(mean_Pt - mean_Ps2);
            HIL_C1t = HIL_C + find(abs([0; TestHIL(HIL_C:HIL_C2t)]) > comp_max2 | ...
                                    abs([0; TestHIL(HIL_C:HIL_C2t)]) < comp_min2, 1, 'last');

            % Refine indices to ensure at least 0.02s after transition
            HIL_B1 = min([HIL_C-1; find(PU(:,1) > PU(HIL_B1t,1) + 0.02, 1)]);
            HIL_C1 = min([HIL_C2t-1; find(PU(:,1) > PU(HIL_C1t,1) + 0.02, 1)]);
            HIL_C2 = min(length(PU(:,1)), HIL_C1 + ceil(2/Ts)); % ensure 2s post-fault window

            % Corresponding ADPSS indices
            ADP_B1 = find(PreData(:,1) >= PU(HIL_B1,1), 1);
            ADP_C1 = find(PreData(:,1) >= PU(HIL_C1,1), 1);
            ADP_C2 = find(PreData(:,1) >= PU(HIL_C2,1), 1);

            %% (Optional) Display segmentation points – commented out
            % plot(PU(:,1),PU(:,nb))
            % hold on;
            % plot(PreData(:,1),PreData(:,nb),'--')
            % plot(PU(HIL_A,1),PU(HIL_A,nb),'bo')
            % plot(PU(HIL_B,1),PU(HIL_B,nb),'bo')
            % plot(PU(HIL_C2,1),PU(HIL_C2,nb),'bo')
            % plot(PU(HIL_B1,1),PU(HIL_B1,nb),'bo')
            % plot(PU(HIL_C1,1),PU(HIL_C1,nb),'bo')
            % pause(1);
            % close;

            %% Compute error indicators (F1~FG)

            % F1: Mean difference in steady-state segments
            F1pre  = abs(mean(TestHIL(HIL_A:HIL_B))   - mean(TestADP(ADP_A:ADP_B)));
            F1tr   = abs(mean(TestHIL(HIL_B1:HIL_C))  - mean(TestADP(ADP_B1:ADP_C)));
            F1post = abs(mean(TestHIL(HIL_C1:HIL_C2)) - mean(TestADP(ADP_C1:ADP_C2)));

            % F2: Mean difference in transition segments
            F2tr   = abs(mean(TestHIL(HIL_B:HIL_B1))  - mean(TestADP(ADP_B:ADP_B1)));
            F2post = abs(mean(TestHIL(HIL_C:HIL_C1))  - mean(TestADP(ADP_C:ADP_C1)));

            % F3: Maximum absolute difference (after interpolation) in each segment
            PreData_int1 = interp1(PreData(ADP_A:ADP_B,1), TestADP(ADP_A:ADP_B), PU(HIL_A:HIL_B,1), 'linear');
            PreData_int2 = interp1(PreData(ADP_B1:ADP_C,1), TestADP(ADP_B1:ADP_C), PU(HIL_B1:HIL_C,1), 'linear');
            PreData_int3 = interp1(PreData(ADP_C1:ADP_C2,1), TestADP(ADP_C1:ADP_C2), PU(HIL_C1:HIL_C2,1), 'linear');

            F3pre = max(abs(TestHIL(HIL_A:HIL_B) - PreData_int1));
            F3tr  = max(abs(TestHIL(HIL_B1:HIL_C) - PreData_int2));
            F3post= max(abs(TestHIL(HIL_C1:HIL_C2) - PreData_int3));

            % Alternative combined F3 (maximum over all segments)
            F3 = max([F3pre; F3tr; F3post]);

            % FA, FB, FC: differences in means over broader intervals (pre-fault, fault, post-fault)
            FA = mean(TestHIL(HIL_A:HIL_B)) - mean(TestADP(ADP_A:ADP_B));
            FB = mean(TestHIL(HIL_B:HIL_C)) - mean(TestADP(ADP_B:ADP_C));
            FC = mean(TestHIL(HIL_C:HIL_C2)) - mean(TestADP(ADP_C:ADP_C2));

            % FG: weighted sum of absolute FA, FB, FC
            FG = abs(FA)*0.1 + abs(FB)*0.6 + abs(FC)*0.3;

            % Store all 9 indicators for current variable (row nb-1)
            F_dvi(nb-1, :) = [F1pre, F3pre, F1tr, F2tr, F3tr, F1post, F2post, F3post, FG];

            % Save F_dvi matrix if requested
            if unit2 == 2
                save(fullfile('../m_tools/DataExport', ['Fdvi', num2str(fig_num)]), 'F_dvi');
            end
        end

        %% Check if results satisfy the predefined standard (Fmax)
        if ~(max(F_dvi > Fmax, [], 'all'))
            disp(['   Pass ', num2str(fig_num), ': ', HIL_name{n}]);
        else
            disp(['!!!Do Not Pass ', num2str(fig_num), ': ', HIL_name{n}]);

            % Display the indicators that exceed thresholds
            Fdviout = F_dvi .* (F_dvi > Fmax);
            Fdviout(Fdviout == 0) = NaN;

            % Format output for display
            formattedString = cellfun(@(x) sprintf('%.4f', x), num2cell(Fdviout), 'UniformOutput', false);
            formattedString(cellfun(@(x) strcmp(x, 'NaN'), formattedString)) = {'  //  '};
            [rows, cols] = size(formattedString);
            formattedString = vertcat({'F1-Pre', 'F3-Pre', 'F1-Trs', 'F2-Trs', 'F3-Trs', 'F1-Pst', 'F2-Pst', 'F3-Pst', '  FG  '}, formattedString);
            leftLabels = {'------'; 'U     '; 'P     '; 'Q     '; 'Id    '; 'Iq    '};
            formattedString = horzcat(leftLabels, formattedString);

            % Print table
            for i = 1:size(formattedString, 1)
                row = formattedString(i, :);
                fprintf('%s    ', row{:});
                fprintf('\n');
            end

            Fdvi_error = Fdvi_error + 1; % increment global error counter
        end

        fig_num = fig_num + 1; % move to next figure number

        clear TestADP TestHIL; % clean up for next iteration
    end
end
%%
disp(['=== Number of Faulted Data in HVRT Check: ', num2str(Fdvi_error), ' ===']);
disp('=============== done ===============');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 