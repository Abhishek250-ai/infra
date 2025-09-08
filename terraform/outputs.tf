output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.alb.dns_name
}

output "patient_target_group_arn" {
  description = "ARN of the Patient target group"
  value       = aws_lb_target_group.patient.arn
}

output "appointment_target_group_arn" {
  description = "ARN of the Appointment target group"
  value       = aws_lb_target_group.appointment.arn
}
