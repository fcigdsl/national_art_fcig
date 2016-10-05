module DeterminingArtEligibility
	include CoreService
	require 'bean'
	require 'json'
	require 'rest_client'                                                           
	require 'bigdecimal'

	def self.confirmed_with_pregnancy(patient)
		actions = []
		valid_condition = true
		
		#Evaluating conditions
		valid_condition = PatientService.evaluate_concept_condition('HIV rapid test result', 'is', 'positive', patient) unless !valid_condition
		valid_condition = PatientService.evaluate_concept_condition('Patient pregnant', 'is', 'true', patient) unless !valid_condition
		
		
		if valid_condition
			actions = []
		
		actions << ['Eligible for therapy', 'ART', 'confirmed with pregnancy']
	
		end
		actions
	end
				
		
	def self.confirmed_and_breastfeeding(patient)
		actions = []
		valid_condition = true
		
		#Evaluating conditions
		valid_condition = PatientService.evaluate_concept_condition('HIV rapid test result', 'is', 'positive', patient) unless !valid_condition
		valid_condition = PatientService.evaluate_concept_condition('Breastfeeding', 'is', 'true', patient) unless !valid_condition
		
		
		if valid_condition
			actions = []
		
		actions << ['Eligible for therapy', 'ART', 'confirmed and breastfeeding']
	
		end
		actions
	end
				
		
	def self.confirmed_with_mild_hiv(patient)
		actions = []
		valid_condition = true
		
		#Evaluating conditions
		valid_condition = PatientService.evaluate_concept_condition('HIV rapid test result', 'is', 'positive', patient) unless !valid_condition
		valid_condition = PatientService.evaluate_concept_condition('WHO stage', 'is', 'WHO Stage 1 or 2', patient) unless !valid_condition
		valid_condition = PatientService.evaluate_concept_condition('CD4 count', '<=', '500', patient, 'cells/mm3') unless !valid_condition
		
		
		if valid_condition
			actions = []
		
		actions << ['Eligible for therapy', 'ART', 'confirmed with mild hiv']
	
		end
		actions
	end
				
		
	def self.confirmed_with_advanced_hiv(patient)
		actions = []
		valid_condition = true
		
		#Evaluating conditions
		valid_condition = PatientService.evaluate_concept_condition('HIV rapid test result', 'is', 'positive', patient) unless !valid_condition
		valid_condition = PatientService.evaluate_concept_condition('WHO stage', 'is', 'WHO Stage 3 or 4', patient) unless !valid_condition
		
		
		if valid_condition
			actions = []
		
		actions << ['Eligible for therapy', 'ART', 'confirmed with advanced hiv']
	
		end
		actions
	end
				
		

	def self.guideline_recommendations(patient)
		alerts = []
		alerts = alerts + confirmed_with_pregnancy(patient)
		alerts = alerts + confirmed_and_breastfeeding(patient)
		alerts = alerts + confirmed_with_mild_hiv(patient)
		alerts = alerts + confirmed_with_advanced_hiv(patient)
		alerts
	end
end
