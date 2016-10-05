module ClinicalGuidelineService
	include CoreService
	require 'bean'
	require 'json'
	require 'rest_client'                                                           
	require 'bigdecimal'

	def self.hiv_with_pregnancy(patient)
		actions = []
		valid_condition = true
		
		valid_condition = PatientService.evaluate_concept_condition('On ART', 'is', 'No', patient) unless !valid_condition
		
		valid_condition = PatientService.evaluate_concept_condition('HIV rapid test result', 'is', 'Positive', patient) unless !valid_condition

		valid_condition = PatientService.evaluate_concept_condition('Is patient pregnant?', 'is', 'Yes', patient) unless !valid_condition
		
		valid_condition = PatientService.evaluate_concept_condition('WHO clinical stage', 'is', 'WHO stage 1/2', patient) unless !valid_condition

		#if !(patient_data('Trimester', patient) == 2 && valid_condition)
		#	valid_condition = false
		#end

		valid_condition = PatientService.evaluate_concept_condition('age', '>=', '5', patient, 'Years') unless !valid_condition 

		if valid_condition
			actions = []

			actions << ['Flag patient for', 'ART', 'HIV with pregnancy']
			actions << ['Prescribe regimen', '1A - D4t/3TC/NVP', 'HIV with pregnancy']

		end
		actions
	end

	def self.adult_CD4_below_threshhold(patient)
		actions = []
		valid_condition = true
		
		valid_condition = PatientService.evaluate_concept_condition('On ART', 'is', 'No', patient) unless !valid_condition
		
		valid_condition = PatientService.evaluate_concept_condition('HIV rapid test result', 'is', 'Positive', patient) unless !valid_condition

        # raise PatientService.evaluate_concept_condition('CD4 Count', '<=', '500', patient).to_yaml

		valid_condition = PatientService.evaluate_concept_condition('CD4 Count', '<=', '350', patient) unless !valid_condition
		
		valid_condition = PatientService.evaluate_concept_condition('age', '>=', '5', patient, 'Years') unless !valid_condition 

		if valid_condition
			actions = []

			actions << ['Flag patient for', 'ART', 'adult CD4 below threshhold']

		end
		actions
	end
=begin
	def self.ART_eligibility_in_patients_from_5_years_with_mild_HIV(patient) 
		alerts = []
		valid_condition = true

		if !(patient_data('On ART', patient) == concept_value('No') && valid_condition)
			valid_condition = false
		end

		if !(patient_data('age', patient, 'Years') >= 5 && valid_condition) # 60 months? TODO
			valid_condition = false
		end

		if !(patient_data('HIV rapid test result', patient) == concept_value('positive') && valid_condition)
			valid_condition = false
		end

		if !(BigDecimal.new(patient_data('CD4 count', patient)) <= 350 && valid_condition)
			valid_condition = false
		end

		if !(patient_data('WHO clinical stage', patient) == concept_value('WHO stage 1/2') && valid_condition)
			valid_condition = false
		end

		if valid_condition
			action_verb = 'Flag patient for' 
			
			# For each action decide how to phrase the alert
			if action_verb == 'Flag patient for'
				alerts << 'Patient is eligible for ' + 'ART' # With its AV complement 
			end
		end
		alerts
	end
=end


	def self.guideline_recommendations(patient)
        alerts = []
		alerts = alerts + hiv_with_pregnancy(patient)
		alerts = alerts + adult_CD4_below_threshhold(patient)
		#alerts = alerts + ART_eligibility_in_patients_from_5_years_with_mild_HIV(patient)
		alerts
	end
end
